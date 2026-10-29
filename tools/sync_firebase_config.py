"""Generate public Firebase client options from downloaded SDK config files.
These app IDs/API keys identify clients; they are not admin credentials.
"""
import json, plistlib
from pathlib import Path
android=Path('config/google-services.updated.json')
ios=Path('config/GoogleService-Info.updated.plist')
if android.exists(): Path('android/app/google-services.json').write_bytes(android.read_bytes())
if ios.exists(): Path('ios/Runner/GoogleService-Info.plist').write_bytes(ios.read_bytes())
a=json.loads(Path('android/app/google-services.json').read_text())
i=plistlib.loads(Path('ios/Runner/GoogleService-Info.plist').read_bytes())
w=json.loads(Path('config/firebase-web.raw.json').read_text())['result'];w=w.get('sdkConfig',w)
if isinstance(w,str): w=json.loads(w)
client=a['client'][0]
web_client=next(o['client_id'] for o in client['oauth_client'] if o['client_type']==3)
configs={'android':{'apiKey':client['api_key'][0]['current_key'],'appId':client['client_info']['mobilesdk_app_id'],'messagingSenderId':a['project_info']['project_number'],'projectId':a['project_info']['project_id'],'storageBucket':a['project_info'].get('storage_bucket','')},'ios':{'apiKey':i['API_KEY'],'appId':i['GOOGLE_APP_ID'],'messagingSenderId':i['GCM_SENDER_ID'],'projectId':i['PROJECT_ID'],'storageBucket':i.get('STORAGE_BUCKET',''),'iosBundleId':i['BUNDLE_ID'],'iosClientId':i['CLIENT_ID']},'web':{k:w[k] for k in ['apiKey','appId','messagingSenderId','projectId','authDomain','storageBucket'] if k in w}}
s="// Generated public Firebase client configuration. Never add service-account keys here.\nimport 'package:firebase_core/firebase_core.dart';\nimport 'package:flutter/foundation.dart';\nclass DefaultFirebaseOptions {\nstatic FirebaseOptions get currentPlatform {\nif(kIsWeb)return web;\nreturn switch(defaultTargetPlatform){TargetPlatform.iOS=>ios,TargetPlatform.android=>android,_=>throw UnsupportedError('Use Android, iOS or web for this app.')};\n}\n"
for name,conf in configs.items():s+=f'static const {name}=FirebaseOptions(\n'+''.join(f'{k}:{json.dumps(str(v))},\n' for k,v in conf.items())+');\n'
s+=f'static const googleServerClientId={json.dumps(web_client)};\nstatic const googleIosClientId={json.dumps(i["CLIENT_ID"])};\n}}\n'
Path('lib/firebase_options.dart').write_text(s)
p=Path('ios/Runner/Info.plist');d=plistlib.loads(p.read_bytes());d['GIDClientID']=i['CLIENT_ID'];d['GIDServerClientID']=web_client;d['CFBundleURLTypes']=[{'CFBundleTypeRole':'Editor','CFBundleURLSchemes':[i['REVERSED_CLIENT_ID']]}];p.write_bytes(plistlib.dumps(d,sort_keys=False))
print('Generated Android/iOS/web Firebase options and iOS Google callback URL.')
