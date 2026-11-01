/** Trusted Spark-compatible Firestore -> RTDB synchronizer. No client credentials.
 * node tools/realtime-admin.cjs sync | watch | deploy-rules
 * Run watch on a trusted workstation/server while using the live app.
 */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const project = 'fixme-ethiopia';
const database = 'https://fixme-ethiopia-default-rtdb.firebaseio.com';
const firestore = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const decode = v => 'stringValue' in v ? v.stringValue : 'booleanValue' in v ? v.booleanValue : 'integerValue' in v ? Number(v.integerValue) : 'doubleValue' in v ? v.doubleValue : 'timestampValue' in v ? Date.parse(v.timestampValue) : 'nullValue' in v ? null : v.arrayValue ? (v.arrayValue.values || []).map(decode) : Object.fromEntries(Object.entries(v.mapValue?.fields || {}).map(([k, v]) => [k, decode(v)]));
async function main() {
  const cache = path.join(process.env.HOME, '.npm/_npx');
  const root = fs.readdirSync(cache).map(x => path.join(cache, x, 'node_modules/firebase-tools/lib')).find(x => fs.existsSync(path.join(x, 'auth.js')));
  if (!root) throw Error('Run npx firebase-tools login first.');
  const auth = require(path.join(root, 'auth.js'));
  const account = auth.getGlobalDefaultAccount();
  if (account?.user?.email !== 'asifalex101@gmail.com') throw Error('Use the Firebase project owner account.');
  async function api(url, method = 'GET', body) {
    const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase', 'https://www.googleapis.com/auth/userinfo.email']);
    const response = await fetch(url, {method, headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json'}, ...(body === undefined ? {} : {body: JSON.stringify(body)})});
    const data = await response.json();
    if (!response.ok) throw Error(data.error?.message || data.error || `Request failed (${response.status})`);
    return data;
  }
  const db = (key, method, data) => api(`${database}/${key}.json`, method, data);
  async function documents(collection) {
    const rows = []; let cursor;
    do {
      const result = await api(`${firestore}/${collection}?pageSize=100${cursor ? `&pageToken=${encodeURIComponent(cursor)}` : ''}`);
      rows.push(...(result.documents || []).map(doc => ({id: doc.name.split('/').pop(), values: Object.fromEntries(Object.entries(doc.fields || {}).map(([k,v]) => [k,decode(v)]))})));
      cursor = result.nextPageToken;
    } while (cursor);
    return rows;
  }
  async function sync() {
    const bookings = await documents('bookings');
    const updates = {};
    const previous = await db('sync/bookings') || {};
    const rooms = await db('rooms') || {};
    const notifications = await db('notifications') || {};
    for (const {id, values: b} of bookings) {
      const participants = [b.customerId, b.technicianId].filter(Boolean);
      if (participants.length === 2) {
        const members = Object.fromEntries(participants.map(uid => [uid, true]));
        if (JSON.stringify(rooms[id]?.members) !== JSON.stringify(members)) updates[`rooms/${id}/members`] = members;
        if (rooms[id]?.meta?.status !== b.status) updates[`rooms/${id}/meta`] = {bookingId: id, categoryId: b.categoryId || '', status: b.status, updatedAt: b.updatedAt || Date.now()};
      } else if (rooms[id]) {
        updates[`rooms/${id}/members`] = null; // Reassignment immediately removes prior access.
      }
      if (previous[id] !== b.status) {
        const event = b.lastEventId || b.status;
        for (const uid of participants) {
          const notificationId = `booking-${id}-${event}`;
          if (!notifications[uid]?.[notificationId]) updates[`notifications/${uid}/${notificationId}`] = {name: `Booking ${b.status.replaceAll('_',' ')}`, text: `${b.categoryId || 'Service'} · ${id}`, type: 'booking', bookingId: id, createdAt: b.updatedAt || b.createdAt || Date.now()};
        }
        updates[`sync/bookings/${id}`] = b.status;
      }
    }
    const bookingIds = new Set(bookings.map(b => b.id));
    for (const id of Object.keys(rooms)) {if (!bookingIds.has(id)) updates[`rooms/${id}/members`] = null;}
    // Deliver any chat alert whose client disconnected after saving its message.
    for (const [id, room] of Object.entries(rooms)) {
      for (const [messageId, message] of Object.entries(room.messages || {})) {
        for (const uid of Object.keys(room.members || {}).filter(uid => uid !== message.senderId)) {
          if (!notifications[uid]?.[`chat-${messageId}`]) updates[`notifications/${uid}/chat-${messageId}`] = {name:'New message', text:message.text, type:'chat', bookingId:id, messageId, senderId:message.senderId, createdAt:message.createdAt};
        }
      }
    }
    if (Object.keys(updates).length) await db('', 'PATCH', updates);
    // FCM HTTP v1 runs only here on the trusted host, never inside Flutter.
    // Receipt tracking prevents resending old alerts on each synchronization.
    const alerts = await db('notifications') || {};
    const delivered = await db('sync/push') || {};
    for (const [uid, feed] of Object.entries(alerts)) {
      const devices = Object.values(feed).some(n => !n.readAt && n.createdAt > Date.now() - 86400000)
        ? await documents(`users/${uid}/devices`) : [];
      for (const [id, notification] of Object.entries(feed)) {
        if (notification.readAt || notification.createdAt < Date.now() - 86400000) continue;
        for (const device of devices) {
          const token = device.values.token;
          if (typeof token !== 'string') continue;
          const hash = crypto.createHash('sha256').update(token).digest('hex');
          if (delivered[uid]?.[id]?.[hash]) continue;
          try {
            await api(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, 'POST', {message:{token, notification:{title:notification.name,body:notification.type === 'chat' ? 'You have a new service message.' : notification.text}, data:{bookingId:notification.bookingId,type:notification.type,notificationId:id}}});
            await db(`sync/push/${uid}/${id}/${hash}`, 'PUT', Date.now());
          } catch (_) {console.error('A device push could not be delivered; the in-app alert remains available.');}
        }
      }
    }
    console.log(`Synchronized ${bookings.length} bookings and realtime alerts.`);
  }
  const command = process.argv[2] || 'sync';
  if (command === 'deploy-rules') {
    const rules = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'database.rules.json'), 'utf8'));
    await db('.settings/rules', 'PUT', rules);
    console.log('Realtime Database security rules deployed.');
  } else if (command === 'sync') { await sync(); }
  else if (command === 'watch') {
    await sync();
    let running = false;
    setInterval(async () => {if (running) return; running = true; try {await sync();} catch(e) {console.error(e.message);} finally {running = false;}}, 15000);
  } else throw Error('Usage: node tools/realtime-admin.cjs sync | watch | deploy-rules');
}
main().catch(e => {console.error(e.message); process.exitCode = 1;});
