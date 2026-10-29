import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, writeBatch, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
let env;
const [host, port]=(process.env.FIRESTORE_EMULATOR_HOST??'127.0.0.1:8080').split(':');
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-fixme-ethiopia',firestore:{host,port:Number(port),rules:readFileSync('../firestore.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();});
const profile=(role)=>({name:'Rule Test',role,approval:role==='customer'?'approved':'incomplete',profileComplete:false,createdAt:serverTimestamp()});
async function create(role,uid='owner'){
 const db=env.authenticatedContext(uid).firestore();const data=profile(role);const batch=writeBatch(db);batch.set(doc(db,'users',uid),data);batch.set(doc(db,role==='customer'?'customers':'technicians',uid),{name:data.name,approval:data.approval,online:false,createdAt:serverTimestamp()});await batch.commit();return db;
}
test('customer can atomically bootstrap own customer profile',async()=>{await assertSucceeds(create('customer'));});
test('technician bootstraps only as incomplete and offline',async()=>{await assertSucceeds(create('technician'));});
test('cannot register as admin',async()=>{const db=env.authenticatedContext('owner').firestore();await assertFails(setDoc(doc(db,'users','owner'),profile('admin')));});
test('cannot approve own technician account',async()=>{const db=env.authenticatedContext('owner').firestore();await assertFails(setDoc(doc(db,'users','owner'),{...profile('technician'),approval:'approved'}));});
test('cannot create another account profile',async()=>{const db=env.authenticatedContext('attacker').firestore();await assertFails(setDoc(doc(db,'users','victim'),profile('customer')));});
test('cannot change role or approval after registration',async()=>{const db=await create('technician');await assertFails(updateDoc(doc(db,'users','owner'),{role:'customer',approval:'approved'}));});
test('can complete own whitelisted profile',async()=>{const db=await create('customer');await assertSucceeds(updateDoc(doc(db,'users','owner'),{name:'Updated name',profile:{'Full name':'Updated name','City':'Addis Ababa'},profileComplete:true,updatedAt:serverTimestamp()}));});
test('cannot include privileged fields in profile completion',async()=>{const db=await create('customer');await assertFails(updateDoc(doc(db,'users','owner'),{profile:{admin:true},profileComplete:true,updatedAt:serverTimestamp()}));});
test('cannot write privileged bookings directly',async()=>{const db=await create('customer');await assertFails(setDoc(doc(db,'bookings','fake'),{customerId:'owner',status:'completed'}));});
async function seedService(){
 await env.withSecurityRulesDisabled(async context=>{
  const db=context.firestore(),batch=writeBatch(db);
  for(const [id,role] of [['customer','customer'],['tech','technician'],['stranger','customer']])batch.set(doc(db,'users',id),{name:id,role,approval:'approved',profileComplete:true});
  batch.set(doc(db,'technicians','tech'),{name:'Real technician',approval:'approved',online:true,skills:['refrigerator']});
  batch.set(doc(db,'service_categories','refrigerator'),{active:true,name:'Refrigerator repair',visitFee:300});
  batch.set(doc(db,'technician_credentials','valid-hash'),{technicianId:'tech',active:true});
  await batch.commit();
 });
}
let eventNumber=0;
async function transitionAs(actor,id,status,extra={},more){
 const db=env.authenticatedContext(actor).firestore(),event=`event-${++eventNumber}`,batch=writeBatch(db);
 batch.update(doc(db,'bookings',id),{status,updatedAt:serverTimestamp(),lastEventId:event,...extra});
 batch.set(doc(db,'bookings',id,'booking_events',event),{status,actorId:actor,createdAt:serverTimestamp()});
 if(more)more(batch,db);await batch.commit();
}
async function requestAssigned(){
 const db=env.authenticatedContext('customer').firestore(),batch=writeBatch(db),event=`event-${++eventNumber}`;
 batch.set(doc(db,'bookings','job'),{customerId:'customer',technicianId:'tech',categoryId:'refrigerator',issue:'Fridge not cooling',scheduledAt:new Date(Date.now()+86400000),status:'assigned',visitFee:300,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),lastEventId:event});
 batch.set(doc(db,'bookings','job','private','address'),{customerId:'customer',address:'Bole, Addis Ababa'});
 batch.set(doc(db,'bookings','job','booking_events',event),{status:'assigned',actorId:'customer',createdAt:serverTimestamp()});
 await batch.commit();
}
test('free-tier workflow verifies assignment, quote approval and cash settlement atomically',async()=>{
 await seedService();await assertSucceeds(requestAssigned());
 await assertSucceeds(transitionAs('tech','job','accepted'));
 await assertFails(transitionAs('tech','job','in_progress'));
 await assertSucceeds(transitionAs('tech','job','on_the_way'));
 await assertSucceeds(transitionAs('tech','job','arrived'));
 await assertFails(transitionAs('stranger','job','identity_verified',{verifiedAt:serverTimestamp(),verifiedCredentialId:'valid-hash',verificationId:'forged'}));
 await assertSucceeds(transitionAs('customer','job','identity_verified',{verifiedAt:serverTimestamp(),verifiedCredentialId:'valid-hash',verificationId:'verification'},(batch,db)=>batch.set(doc(db,'qr_verifications','verification'),{bookingId:'job',customerId:'customer',technicianId:'tech',credentialId:'valid-hash',matched:true,createdAt:serverTimestamp()})));
 await assertSucceeds(transitionAs('tech','job','in_progress'));
 await assertFails(transitionAs('tech','job','work_completed'));
 await assertSucceeds(transitionAs('tech','job','quote_pending',{quoteId:'quote'},(batch,db)=>batch.set(doc(db,'quotes','quote'),{bookingId:'job',customerId:'customer',technicianId:'tech',visit:300,labor:600,parts:450,total:1350,description:'Replace cooling relay',status:'pending',createdAt:serverTimestamp()})));
 await assertSucceeds(transitionAs('customer','job','in_progress',{quoteApprovedAt:serverTimestamp(),approvedTotal:1350},(batch,db)=>batch.update(doc(db,'quotes','quote'),{status:'approved',respondedAt:serverTimestamp()})));
 await assertSucceeds(transitionAs('tech','job','work_completed'));
 await assertSucceeds(transitionAs('customer','job','customer_confirmed'));
 await assertSucceeds(transitionAs('customer','job','payment_pending',{},(batch,db)=>batch.set(doc(db,'payments','job'),{bookingId:'job',customerId:'customer',technicianId:'tech',amount:1350,method:'cash',status:'customer_reported',createdAt:serverTimestamp()})));
 await assertSucceeds(transitionAs('tech','job','completed',{completedAt:serverTimestamp()},(batch,db)=>batch.update(doc(db,'payments','job'),{status:'settled',settledAt:serverTimestamp()})));
});
test('prices cannot be forged when a customer creates a booking',async()=>{
 await seedService();const db=env.authenticatedContext('customer').firestore();
 await assertFails(setDoc(doc(db,'bookings','forged'),{customerId:'customer',technicianId:null,categoryId:'refrigerator',issue:'repair',scheduledAt:new Date(Date.now()+86400000),status:'requested',visitFee:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),lastEventId:'fake'}));
});
test('KYC documents are invisible to other signed-in accounts',async()=>{
 await seedService();const owner=env.authenticatedContext('tech').firestore();await assertSucceeds(setDoc(doc(owner,'private_media','id-photo'),{ownerId:'tech',kind:'kyc',bookingId:'',base64:'abcd',createdAt:serverTimestamp()}));
 const {getDoc}=await import('firebase/firestore');await assertFails(getDoc(doc(env.authenticatedContext('customer').firestore(),'private_media','id-photo')));
});
test('technician application requires owned identity images and a profile photo',async()=>{
 const db=await create('technician','applicant');
 for(const [id,kind] of [['portrait','profile'],['front','kyc'],['back','kyc']])await setDoc(doc(db,'private_media',id),{ownerId:'applicant',kind,bookingId:'',base64:'test-image',createdAt:serverTimestamp()});
 const batch=writeBatch(db);batch.update(doc(db,'users','applicant'),{approval:'pending',updatedAt:serverTimestamp()});batch.update(doc(db,'technicians','applicant'),{approval:'pending',skills:['refrigerator'],online:false});batch.set(doc(db,'technician_private','applicant'),{profile:{experience:'5 years'},documents:['front','back'],photoId:'portrait',submittedAt:serverTimestamp()});await assertSucceeds(batch.commit());await assertFails(updateDoc(doc(db,'users','applicant'),{approval:'approved'}));
});
