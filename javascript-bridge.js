// Keep Promise ownership in JavaScript: HBuilderX 5.33 can lose a rejected
// native Deferred before it reaches the caller's catch handler.
export function createMeshStreamFacade(native) {
  function invoke(operation, args = {}) {
    return new Promise((resolve, reject) => {
      native.invoke(operation, args, (payload) => {
        try {
          const result = JSON.parse(payload)
          if (result.ok !== true) throw new Error(result.error || 'MeshStream request failed')
          resolve(result.value)
        } catch (error) {
          reject(error)
        }
      })
    })
  }

  function duration(value) {
    if (!Number.isFinite(value) || value < 0) throw new Error('Duration must be finite and non-negative')
    return Math.floor(value)
  }

  return class MeshStream {
    static getSdkVersion() { return invoke('getSdkVersion') }
    static create(config) { return invoke('create', config) }
    static async createPlaybackSession(clientId, options) {
      return invoke('createPlaybackSession', { clientId, optionsJson: JSON.stringify(options) })
    }
    static getStatus(clientId) { return invoke('getStatus', { clientId }) }
    static getStats(clientId, sessionId) { return invoke('getStats', { clientId, sessionId }) }
    static getDiagnostics(clientId, sessionId) { return invoke('getDiagnostics', { clientId, sessionId }) }
    static preload(clientId, sessionId) { return invoke('preload', { clientId, sessionId }) }
    static setP2pEnabled(clientId, sessionId, enabled) { return invoke('setP2pEnabled', { clientId, sessionId, enabled }) }
    static async updateCurrentPositionMs(clientId, sessionId, positionMs) {
      return invoke('updateCurrentPositionMs', { clientId, sessionId, positionMs: duration(positionMs) })
    }
    static async updateBufferedDurationMs(clientId, sessionId, durationMs) {
      return invoke('updateBufferedDurationMs', { clientId, sessionId, durationMs: duration(durationMs) })
    }
    static closeSession(clientId, sessionId) { return invoke('closeSession', { clientId, sessionId }) }
    static closeClient(clientId) { return invoke('closeClient', { clientId }) }
    static subscribeEvents(listener) { return native.subscribeEvents(listener) }
    static unsubscribeEvents(id) { native.unsubscribeEvents(id) }
    static addEventListener(listener) {
      const id = this.subscribeEvents(listener)
      return () => this.unsubscribeEvents(id)
    }
  }
}
