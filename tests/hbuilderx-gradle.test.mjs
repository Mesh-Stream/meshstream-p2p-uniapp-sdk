import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, chmodSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'
import test from 'node:test'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const setup = path.join(root, 'scripts/configure-hbuilderx-gradle.py')
const launcher = path.join(root, 'scripts/hbuilderx-gradle.sh')
const setting = 'uts-development-android.gradleHome'

function fixture(t) {
  const dir = mkdtempSync(path.join(tmpdir(), 'meshstream gradle '))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const settings = path.join(dir, 'settings.json'), config = path.join(dir, 'config.json')
  const executable = path.join(dir, 'gradle wrapper')
  writeFileSync(executable, '#!/bin/sh\nprintf "%s\\n" "$@"\n')
  chmodSync(executable, 0o700)
  writeFileSync(settings, JSON.stringify({ [setting]: executable, 'editor.fontSize': 16 }))
  const run = (...args) => spawnSync('python3', [setup, '--settings', settings, '--config', config, ...args], { encoding: 'utf8' })
  return { dir, settings, config, executable, run }
}

test('setup survives GUI environment, is idempotent and restores only its setting', t => {
  const f = fixture(t)
  assert.equal(f.run().status, 0)
  assert.equal(f.run().status, 0)
  const values = JSON.parse(readFileSync(f.settings))
  assert.equal(values[setting], launcher)
  assert.equal(values['editor.fontSize'], 16)
  assert.equal(JSON.parse(readFileSync(f.config)).previousGradle, f.executable)
  values['editor.fontSize'] = 18
  writeFileSync(f.settings, JSON.stringify(values))
  assert.equal(f.run('--restore').status, 0)
  assert.deepEqual(JSON.parse(readFileSync(f.settings)), { [setting]: f.executable, 'editor.fontSize': 18 })
  assert.equal(existsSync(f.config), false)
})

test('restore does not overwrite a later Gradle choice', t => {
  const f = fixture(t)
  assert.equal(f.run().status, 0)
  writeFileSync(f.settings, JSON.stringify({ [setting]: '/another/gradle' }))
  assert.notEqual(f.run('--restore').status, 0)
  assert.equal(JSON.parse(readFileSync(f.settings))[setting], '/another/gradle')
  assert.equal(existsSync(f.config), true)
})

test('invalid executable and invalid settings leave user files untouched', t => {
  const f = fixture(t), original = readFileSync(f.settings, 'utf8')
  assert.notEqual(f.run('--gradle', launcher).status, 0)
  assert.equal(readFileSync(f.settings, 'utf8'), original)
  assert.equal(existsSync(f.config), false)
  writeFileSync(f.settings, '// not JSON')
  assert.notEqual(f.run().status, 0)
  assert.equal(readFileSync(f.settings, 'utf8'), '// not JSON')
})

test('launcher uses saved executable with spaces and limits repository changes to HBuilderX', t => {
  const f = fixture(t)
  assert.equal(f.run().status, 0)
  const env = { ...process.env, MESHSTREAM_GRADLE_EXECUTABLE: '', MESHSTREAM_HBUILDERX_GRADLE_CONFIG: f.config }
  for (const [suffix, expected] of [['.uts-development-android/gradle/test', 'PREFER_PROJECT'], ['ordinary-project', 'PREFER_SETTINGS']]) {
    const cwd = path.join(f.dir, suffix)
    mkdirSync(cwd, { recursive: true })
    writeFileSync(path.join(cwd, 'settings.gradle'), 'repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)')
    const result = spawnSync('bash', [launcher, '--version', 'argument with spaces'], { cwd, env, encoding: 'utf8' })
    assert.equal(result.status, 0, result.stderr)
    assert.equal(result.stdout, '--version\nargument with spaces\n')
    assert.ok(readFileSync(path.join(cwd, 'settings.gradle'), 'utf8').includes(expected))
  }
})
