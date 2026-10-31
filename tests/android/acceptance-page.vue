<template><scroll-view scroll-y style="padding:20px"><text v-for="(line,i) in lines" :key="i" style="display:block;font-size:12px">{{line}}</text></scroll-view></template>
<script setup>
import {ref,onMounted} from 'vue'
import {MeshStream} from '@/uni_modules/meshstream-p2p/javascript.js'
const lines=ref([]), checks=[], active=[]
const base='http://127.0.0.1:18116'
let eventCount=0,remove=null
function obj(v){return JSON.parse(JSON.stringify(v))}
function req(url,options={}){return new Promise((resolve,reject)=>uni.request({url,timeout:12000,...options,success:r=>r.statusCode===200?resolve(r.data):reject(new Error('HTTP '+r.statusCode+' '+url)),fail:reject}))}
function log(name,data){const item={time:Date.now(),name,data};console.log('MESH_ACCEPT '+JSON.stringify(item));lines.value.push(name+' '+JSON.stringify(data));req(base+'/event',{method:'POST',data:item}).catch(()=>{})}
function check(name,ok,data={}){const x={name,ok,...data};checks.push(x);log('check',x)}
const delay=ms=>new Promise(r=>setTimeout(r,ms))
async function call(name,fn,ms=8000){const start=Date.now();let timer;try{const result=await Promise.race([Promise.resolve().then(fn),new Promise((_,rej)=>{timer=setTimeout(()=>rej(new Error(name+' timed out')),ms)})]);log('call',{name,ms:Date.now()-start});return result}finally{clearTimeout(timer)}}
async function stats(c,s){return obj(await call('stats',()=>MeshStream.getStats(c.clientId,s.sessionId)))}
async function client(enabled){const c=await call('create',()=>MeshStream.create({key:'SUPPLY_TEST_KEY_IN_PRIVATE_STAGING_ONLY',p2pEnabled:enabled}));active.push(c);return c}
async function ready(c){let status;for(let i=0;i<25;i++){status=obj(await call('status',()=>MeshStream.getStatus(c.clientId)));if(status.trackerPoolReady&&status.effectiveP2pEnabled)return status;await delay(500)}return status}
function uris(s){return s.split(/\r?\n/).map(x=>x.trim()).filter(x=>x&&!x.startsWith('#'))}
async function playlist(s){const text=await req(s.playbackUrl);const list=uris(text);if(!list.every(u=>u.startsWith('http://127.0.0.1:')))throw new Error('Expected rewritten proxy segment URLs');return list}
async function segment(list,source,i){const data=await req(list[i],{responseType:'arraybuffer'});const result=await req(base+'/verify',{method:'POST',data:{path:source[i],data:uni.arrayBufferToBase64(data)}});check('segment-integrity-'+i,result.ok,{bytes:result.bytes,sha256:result.sha256});return result.bytes}
onMounted(async()=>{
 const runId='uniapp-android-'+Date.now();let a,b,c,sa,sb,sc,al,bl,cl,initialEvents
 try{
  check('native-version',(await call('version',()=>MeshStream.getSdkVersion()))==='1.0.7')
  a=await client(true)
  const subscriptionId=MeshStream.subscribeEvents(e=>{eventCount++;const value=obj(e);if(value.type!=='statistics')log('sdk-event',value)});remove=()=>MeshStream.unsubscribeEvents(subscriptionId)
  const url=base+'/index.m3u8', source=uris(await req(url))
  sa=await call('create-seeder-session',()=>MeshStream.createPlaybackSession(a.clientId,{url,contentId:runId,mimeType:'m3u8'}))
  const pre=await call('preload',()=>MeshStream.preload(a.clientId,sa.sessionId),15000);check('preload',pre===true)
  const config=await ready(a);check('configuration',config.effectiveP2pEnabled===true,{status:config})
  al=await playlist(sa)
  for(let i=0;i<7;i++)await segment(al,source,i)
  const before=await stats(a,sa);check('seeder-http',before.httpDownloaded>0,{stats:before})
  b=await client(true)
  sb=await call('create-receiver-session',()=>MeshStream.createPlaybackSession(b.clientId,{url,contentId:runId,mimeType:'m3u8'}));bl=await playlist(sb);await ready(b)
  await segment(bl,source,0)
  let receiver,seeder
  for(let i=0;i<30;i++){receiver=await stats(b,sb);seeder=await stats(a,sa);if(receiver.connectedPeers>0&&seeder.connectedPeers>0)break;await delay(500)}
  check('peer-connected',receiver.connectedPeers>0,{receiver,seeder})
  for(let i=1;i<7;i++)await segment(bl,source,i)
  await delay(1200);receiver=await stats(b,sb);seeder=await stats(a,sa)
  check('p2p-download',receiver.p2pDownloaded>0,{stats:receiver});check('p2p-upload',seeder.p2pUploaded>0,{stats:seeder})
  await call('close-seeder-session',()=>MeshStream.closeSession(a.clientId,sa.sessionId));await call('close-seeder-client',()=>MeshStream.closeClient(a.clientId))
  const still=await stats(b,sb);check('client-isolation',still.httpDownloaded+still.p2pDownloaded>0)
  await delay(1500);const preFallback=await stats(b,sb);await segment(bl,source,9);const afterFallback=await stats(b,sb)
  check('cdn-fallback',afterFallback.httpDownloaded>preFallback.httpDownloaded,{before:preFallback,after:afterFallback})
  c=await client(false);sc=await call('create-cdn-session',()=>MeshStream.createPlaybackSession(c.clientId,{url,contentId:runId+'-cdn',mimeType:'m3u8'}));cl=await playlist(sc);await segment(cl,source,0);await segment(cl,source,1)
  const cdn=await stats(c,sc);check('p2p-disabled',cdn.p2pDownloaded===0&&cdn.httpDownloaded>0,{stats:cdn})
  const diag=obj(await call('diagnostics',()=>MeshStream.getDiagnostics(b.clientId,sb.sessionId)));check('diagnostics',typeof diag.fallbackCount==='number',{diagnostics:diag})
  await call('disable-p2p',()=>MeshStream.setP2pEnabled(b.clientId,sb.sessionId,false));await call('enable-p2p',()=>MeshStream.setP2pEnabled(b.clientId,sb.sessionId,true));check('p2p-toggle',true)
  await call('position',()=>MeshStream.updateCurrentPositionMs(b.clientId,sb.sessionId,10000));await call('buffer',()=>MeshStream.updateBufferedDurationMs(b.clientId,sb.sessionId,20000))
  remove();remove=null;await delay(1500);initialEvents=eventCount;await delay(2500);check('event-unsubscribe',initialEvents===eventCount,{before:initialEvents,after:eventCount})
  await call('close-receiver',()=>MeshStream.closeSession(b.clientId,sb.sessionId));await call('close-receiver-repeat',()=>MeshStream.closeSession(b.clientId,sb.sessionId))
  let rejected=false;try{await call('stats-closed',()=>MeshStream.getStats(b.clientId,sb.sessionId))}catch(e){rejected=!String(e).includes('timed out');log('closed-stats-error',String(e))}check('closed-session-rejected',rejected)
  await call('close-receiver-client',()=>MeshStream.closeClient(b.clientId));await call('close-cdn-client',()=>MeshStream.closeClient(c.clientId))
  let closed=false;try{await req(sb.playbackUrl,{timeout:2000})}catch(e){closed=true}check('proxy-released',closed)
 }catch(e){check('unexpected-error',false,{error:String(e)})}
 finally{
  if(remove)try{remove()}catch(e){}
  for(const item of active)try{await call('final-close',()=>MeshStream.closeClient(item.clientId),4000)}catch(e){log('cleanup-error',String(e))}
  log('summary',{runId,pass:checks.every(x=>x.ok),checks,eventCount})
 }
})
</script>
