from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse,json,base64,hashlib,time
parser=argparse.ArgumentParser()
parser.add_argument('--media',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
BASE=args.media.resolve()
OUT=args.output.resolve()
OUT.mkdir(parents=True,exist_ok=True)
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(BASE),**kwargs)
 def do_POST(self):
  payload=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  if self.path=='/verify':
   raw=base64.b64decode(payload['data']); source=(BASE/payload['path']).resolve()
   if BASE not in source.parents: self.send_error(400); return
   expected=source.read_bytes()
   result={'ok':raw==expected,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
  else:
   with (OUT/'acceptance-events.jsonl').open('a') as f:f.write(json.dumps(payload)+'\n')
   result={'ok':True}
  data=json.dumps(result).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def copyfile(self,source,outputfile):
  if not self.path.split('?')[0].endswith('.ts'):return super().copyfile(source,outputfile)
  try:
   while True:
    block=source.read(16384)
    if not block:break
    outputfile.write(block);outputfile.flush();time.sleep(len(block)/262144)
  except (BrokenPipeError,ConnectionResetError):pass
ThreadingHTTPServer(('127.0.0.1',18116),Handler).serve_forever()
