import { MeshStream as NativeMeshStream } from '@/uni_modules/meshstream-p2p'
import { createMeshStreamFacade } from './javascript-bridge.js'

export const MeshStream = createMeshStreamFacade(NativeMeshStream)
