Firebase = require 'firebase'
jdp      = require 'jsondiffpatch'

emptyobj = (v) ->
  return false for own k, v of v
  true

tof = ( v ) -> 
  if (t = typeof v) is 'object'
    return 'null' if v is null
    return 'empty_object' if emptyobj v
  t

module.exports = sync_firebase_value_once = ( ref, new_value ) ->
  switch tof new_value
    when 'null'
      ref.remove()
      return
    when 'empty_object'
      ref.remove()
      return
    when 'object'
      sync_firebase_object_once ref, new_value
    else
      ref.set new_value

sync_firebase_object_once = ( ref, new_object ) ->
  ref.once 'value', (snap) ->
    val    = snap.val()
    is_obj = ( typeof val is 'object' ) and val isnt null
    val    = {} unless is_obj
    delta  = jdp.diff val, new_object
    txs    = get_firebase_transactions ref, delta
    apply_firebase_transactions txs
    cb? null, txs

get_firebase_transactions = ( ref, delta ) ->
  base_url = ref.toString()
  tx = []
  do iter = ( base_url, delta ) ->
    for own k, v of delta then do (k, v) ->
      url = base_url + '/' + k
      if v instanceof Array
        switch v.length
          when 1 # created
            tx.push ['add', url, v[0]]
          when 2 # modified
            tx.push ['modify', url, v[0], v[1]]
          when 3 # deleted
            tx.push ['delete', url]
      else
        iter url, v
  tx

apply_firebase_transactions = ( txs ) ->
  for tx in txs then do ( tx ) ->
    ref = new Firebase tx[1]
    switch tx[0]
      when 'add'
        ref.set tx[2]
      when 'modify'
        ref.set tx[3] # TODO: compare and swap
      when 'delete'
        ref.remove()
