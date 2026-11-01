import {readFileSync} from 'node:fs';
import {before, after, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {ref, set, get, update, serverTimestamp, remove} from 'firebase/database';
let env;
before(async () => {
  const [host, port] = (process.env.FIREBASE_DATABASE_EMULATOR_HOST || '127.0.0.1:9000').split(':');
  env = await initializeTestEnvironment({projectId:'demo-fixme-ethiopia', database:{host, port:Number(port), rules:readFileSync(new URL('../../database.rules.json', import.meta.url),'utf8')}});
});
after(async () => {await env?.cleanup();});
beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async context => set(ref(context.database()), {
    rooms:{booking:{members:{customer:true,technician:true},meta:{status:'assigned'}}},
    notifications:{customer:{existing:{name:'Booking assigned',text:'Your technician is ready',type:'booking',bookingId:'booking',createdAt:1}}},
  }));
});
const db = uid => env.authenticatedContext(uid).database();
const message = (senderId='customer', text='Hello') => ({senderId,text,createdAt:serverTimestamp()});
test('only assigned participants can read and send chat messages', async () => {
  await assertFails(get(ref(env.unauthenticatedContext().database(),'rooms/booking')));
  await assertFails(get(ref(db('outsider'),'rooms/booking')));
  await assertFails(set(ref(db('outsider'),'rooms/booking/messages/x'), message('outsider')));
  await assertSucceeds(set(ref(db('customer'),'rooms/booking/messages/x'), message()));
  assert.equal((await assertSucceeds(get(ref(db('technician'),'rooms/booking/messages/x')))).val().text,'Hello');
});
test('messages cannot spoof identity, edit history, delete, or exceed length limits', async () => {
  await assertFails(set(ref(db('customer'),'rooms/booking/messages/spoof'), message('technician')));
  await assertFails(set(ref(db('customer'),'rooms/booking/messages/long'), message('customer','x'.repeat(2001))));
  await assertFails(set(ref(db('customer'),'rooms/booking/messages/empty'), message('customer','')));
  await assertFails(set(ref(db('customer'),'rooms/booking/messages/backdated'), {...message(), createdAt:1}));
  await assertSucceeds(set(ref(db('customer'),'rooms/booking/messages/x'), message()));
  await assertFails(update(ref(db('customer'),'rooms/booking/messages/x'), {text:'Changed'}));
  await assertFails(remove(ref(db('customer'),'rooms/booking/messages/x')));
});
test('membership, read receipts, typing and online presence are owner restricted', async () => {
  await assertFails(set(ref(db('outsider'),'rooms/booking/members/outsider'), true));
  await assertFails(set(ref(db('customer'),'rooms/booking/members/outsider'), true));
  for (const [path,value] of [['reads',serverTimestamp()],['typing',serverTimestamp()],['presence',true]]) {
    await assertSucceeds(set(ref(db('customer'),`rooms/booking/${path}/customer`),value));
    await assertFails(set(ref(db('customer'),`rooms/booking/${path}/technician`),value));
  }
  await assertSucceeds(remove(ref(db('customer'),'rooms/booking/typing/customer')));
});
test('notification feed is private and only its owner can mark items read', async () => {
  await assertFails(get(ref(db('technician'),'notifications/customer')));
  await assertSucceeds(get(ref(db('customer'),'notifications/customer')));
  await assertFails(set(ref(db('technician'),'notifications/customer/existing/readAt'),serverTimestamp()));
  await assertSucceeds(set(ref(db('customer'),'notifications/customer/existing/readAt'),serverTimestamp()));
  await assertFails(update(ref(db('customer'),'notifications/customer/existing'),{text:'Forged'}));
  await assertFails(set(ref(db('customer'),'notifications/customer/fake'),{name:'Fake',text:'Fake',type:'booking',bookingId:'booking',createdAt:serverTimestamp()}));
});
test('a real persisted message permits one matching notification for its recipient', async () => {
  await assertSucceeds(set(ref(db('customer'),'rooms/booking/messages/m1'), message()));
  const payload = {name:'New message',text:'Hello',type:'chat',bookingId:'booking',messageId:'m1',senderId:'customer',createdAt:serverTimestamp()};
  await assertFails(set(ref(db('customer'),'notifications/outsider/chat-m1'),payload));
  await assertFails(set(ref(db('customer'),'notifications/technician/chat-wrong'),payload));
  await assertFails(set(ref(db('customer'),'notifications/technician/chat-m1'),{...payload,text:'Forged text'}));
  await assertSucceeds(set(ref(db('customer'),'notifications/technician/chat-m1'),payload));
  await assertFails(set(ref(db('customer'),'notifications/technician/chat-m1'),payload));
  await assertSucceeds(set(ref(db('technician'),'notifications/technician/chat-m1/readAt'),serverTimestamp()));
});
