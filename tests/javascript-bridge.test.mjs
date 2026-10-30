import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFile } from 'node:fs/promises'
const source = await readFile(new URL('../javascript-bridge.js', import.meta.url), 'utf8')
const { createMeshStreamFacade } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'))

test('native failure rejects the JavaScript Promise, including delayed replies', async () => {
  const sdk = createMeshStreamFacade({ invoke(operation, args, complete) {
    setTimeout(() => complete(JSON.stringify({ ok: false, error: 'Unknown or closed session' })), 1)
  } })
  await assert.rejects(sdk.getStats('client', 'closed'), /Unknown or closed session/)
})
test('malformed replies reject instead of leaving the request pending', async () => {
  const sdk = createMeshStreamFacade({ invoke(operation, args, complete) { complete('invalid JSON') } })
  await assert.rejects(sdk.getStatus('client'), SyntaxError)
})
test('session options and false P2P flags reach the native transport', async () => {
  const calls = []
  const sdk = createMeshStreamFacade({ invoke(operation, args, complete) {
    calls.push({ operation, args }); complete(JSON.stringify({ ok: true, value: { sessionId: 'session' } }))
  } })
  assert.deepEqual(await sdk.createPlaybackSession('client', { url: 'https://example.test/a.m3u8', originHeaders: { Accept: 'video/*' } }), { sessionId: 'session' })
  assert.equal(JSON.parse(calls[0].args.optionsJson).originHeaders.Accept, 'video/*')
  await sdk.setP2pEnabled('client', 'session', false)
  assert.equal(calls[1].args.enabled, false)
})
test('unsubscribe works for subscription zero and repeated calls', () => {
  const removed = []
  const sdk = createMeshStreamFacade({ subscribeEvents() { return 0 }, unsubscribeEvents(id) { removed.push(id) } })
  const remove = sdk.addEventListener(() => {})
  remove(); remove()
  assert.deepEqual(removed, [0, 0])
})
test('invalid player durations never reach native and valid values are integral', async () => {
  const calls = []
  const sdk = createMeshStreamFacade({ invoke(operation, args, complete) {
    calls.push(args); complete(JSON.stringify({ ok: true, value: null }))
  } })
  for (const value of [-1, NaN, Infinity]) await assert.rejects(sdk.updateBufferedDurationMs('c', 's', value), /finite and non-negative/)
  assert.equal(calls.length, 0)
  await sdk.updateCurrentPositionMs('c', 's', 123.9)
  assert.equal(calls[0].positionMs, 123)
})
