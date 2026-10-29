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
