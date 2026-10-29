/** Trusted, local project-owner administration. No server, billing, or key file.
 * Uses the existing Firebase CLI session; never put this script's OAuth token in
 * Flutter. Commands: seed-catalog | approve UID | assign BOOKING UID | revoke HASH.
 */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project='fixme-ethiopia',base=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const encode=value=>value===null?{nullValue:null}:typeof value==='string'?{stringValue:value}:typeof value==='boolean'?{booleanValue:value}:typeof value==='number'?{integerValue:String(value)}:Array.isArray(value)?{arrayValue:{values:value.map(encode)}}:value.$timestamp?{timestampValue:value.$timestamp}:{mapValue:{fields:Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]))}};
const decode=value=>'stringValue'in value?value.stringValue:'booleanValue'in value?value.booleanValue:'integerValue'in value?Number(value.integerValue):'timestampValue'in value?value.timestampValue:'nullValue'in value?null:value.arrayValue?(value.arrayValue.values??[]).map(decode):Object.fromEntries(Object.entries(value.mapValue?.fields??{}).map(([k,v])=>[k,decode(v)]));
(async()=>{
 const cache=path.join(process.env.HOME,'.npm/_npx'),root=fs.readdirSync(cache).map(x=>path.join(cache,x,'node_modules/firebase-tools/lib')).find(x=>fs.existsSync(path.join(x,'auth.js')));
 if(!root)throw Error('Run npx firebase-tools login first.');
 const auth=require(path.join(root,'auth.js')),account=auth.getGlobalDefaultAccount();
 if(account?.user?.email!=='asifalex101@gmail.com')throw Error('Use the project owner Firebase CLI account asifalex101@gmail.com.');
 const token=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
 async function api(url,method='GET',body){const response=await fetch(url,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});const data=await response.json();if(!response.ok)throw Error(data.error?.message??response.status);return data;}
 const get=async name=>{const d=await api(`${base}/${name}`);return {data:Object.fromEntries(Object.entries(d.fields??{}).map(([k,v])=>[k,decode(v)])),updateTime:d.updateTime};};
 const write=(name,data,updateTime)=>({update:{name:`projects/${project}/databases/(default)/documents/${name}`,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,encode(v)]))},updateMask:{fieldPaths:Object.keys(data)},...(updateTime?{currentDocument:{updateTime}}:{})});
 const commit=writes=>api(`${base}:commit`,'POST',{writes});
 const now={$timestamp:new Date().toISOString()},[command,a,b]=process.argv.slice(2);
 if(command==='seed-catalog'){
  const categories=[['refrigerator','Refrigerator Repair'],['electrical','Electrical Repair'],['ac','AC Repair'],['satellite','Satellite Dish'],['plumbing','Plumbing'],['tv','TV Repair'],['washing','Washing Machine'],['cctv','CCTV'],['water-pump','Water Pump'],['computer','Computer Repair'],['microwave','Microwave'],['other','Other Repairs']];
  await commit([...categories.map(([id,name])=>write(`service_categories/${id}`,{name,active:true,visitFee:300})),...['Bole','Arada','Kirkos','Yeka','Nifas Silk'].map(name=>write(`service_areas/${name.toLowerCase().replaceAll(' ','-')}`,{name,city:'Addis Ababa',countryCode:'ET',active:true}))]);console.log('Saved 12 service categories and 5 Addis Ababa service areas. Initial visit fees: ETB 300; editable by the project owner.');
 }else if(command==='approve'&&a){
  const [u,t,p]=await Promise.all([get(`users/${a}`),get(`technicians/${a}`),get(`technician_private/${a}`)]);
  if(u.data.role!=='technician'||u.data.approval!=='pending'||(p.data.documents??[]).length<2)throw Error('A pending technician application with reviewed documents is required.');
  const raw=crypto.randomBytes(32).toString('hex'),hash=crypto.createHash('sha256').update(raw).digest('hex');
  await commit([write(`users/${a}`,{approval:'approved',updatedAt:now},u.updateTime),write(`technicians/${a}`,{approval:'approved',approvedAt:now,...(p.data.photoId?{photoId:p.data.photoId}:{})},t.updateTime),write(`technician_private/${a}`,{badgeToken:raw},p.updateTime),write(`technician_credentials/${hash}`,{technicianId:a,active:true,issuedAt:now}),write(`audit_logs/${crypto.randomUUID()}`,{action:'approveTechnician',technicianId:a,actorEmail:account.user.email,createdAt:now})]);console.log('Technician approved. The credential is available only in their signed-in ID card.');
 }else if(command==='assign'&&a&&b){
  const [booking,tech]=await Promise.all([get(`bookings/${a}`),get(`technicians/${b}`)]);if(!['requested','searching'].includes(booking.data.status)||tech.data.approval!=='approved')throw Error('Booking must await assignment and technician must be approved.');
  const event=crypto.randomUUID();await commit([write(`bookings/${a}`,{technicianId:b,status:'assigned',updatedAt:now,lastEventId:event},booking.updateTime),write(`bookings/${a}/booking_events/${event}`,{status:'assigned',actorId:'project-owner',createdAt:now})]);console.log('Booking assigned.');
 }else if(command==='revoke'&&a){await commit([write(`technician_credentials/${a}`,{active:false,revokedAt:now})]);console.log('Credential revoked.');}
 else throw Error('Usage: node tools/admin.cjs seed-catalog | approve TECHNICIAN_UID | assign BOOKING_ID TECHNICIAN_UID | revoke CREDENTIAL_HASH');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
