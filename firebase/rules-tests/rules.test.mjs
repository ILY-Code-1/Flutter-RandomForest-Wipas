// Firestore security rules tests (run against the local emulator only).
//   cd firebase/rules-tests && npm install && npm run test:emulator
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-wipas';
const WH = 'WH-CKG-01';
const PRED = `pred_${WH}_20261009`;
const ROLES = ['admin', 'manajer', 'supervisor', 'viewer'];

let env;

const db = (role) => env.authenticatedContext(`uid-${role}`).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const actualUpdate = (role, value = 17560) => ({
  actual_inbound: value,
  actual_note: null,
  actual_input_by: `uid-${role}`,
  actual_input_at: serverTimestamp(),
});

const validConfig = (role) => ({
  capacity_rider: 400,
  capacity_driver: 800,
  capacity_op_inbound: 500,
  capacity_op_outbound: 650,
  ratio_rider: 0.7,
  ratio_driver: 0.3,
  rounding: 'ceil',
  updated_by: `uid-${role}`,
  updated_at: serverTimestamp(),
});

const decision = (role, extra = {}) => ({
  pred_id: PRED,
  wh_id: WH,
  decided_by: `uid-${role}`,
  decided_by_name: role,
  decision: 'approved',
  manpower_final: { rider: 37, driver: 7, op_inbound: 37, op_outbound: 31 },
  reason: null,
  decided_at: serverTimestamp(),
  ...extra,
});

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const role of ROLES) {
      await setDoc(doc(fs, 'users', `uid-${role}`), { role, display_name: role, email: `${role}@x`, wh_id: WH });
    }
    await setDoc(doc(fs, 'predictions', PRED), {
      wh_id: WH,
      target_date: '2026-10-09',
      predicted: 18420,
      projection: 15900,
      deviation_pct: 15.8,
      alert: true,
      manpower: { rider: 37, driver: 7, op_inbound: 37, op_outbound: 31 },
    });
    await setDoc(doc(fs, 'operational_configs', WH), {
      capacity_rider: 350,
      capacity_driver: 800,
      capacity_op_inbound: 500,
      capacity_op_outbound: 600,
      ratio_rider: 0.7,
      ratio_driver: 0.3,
      rounding: 'ceil',
      updated_by: 'seed',
      updated_at: new Date(),
    });
    await setDoc(doc(fs, 'decision_logs', 'd1'), decision('manajer', { decided_at: new Date() }));
    await setDoc(doc(fs, 'config_history', 'h1'), { wh_id: WH, changed_by: 'uid-manajer', changed_at: new Date() });
    await setDoc(doc(fs, 'notifications', `deviation_${WH}_20261009`), {
      type: 'deviation',
      title: 'Deviasi',
      body: 'x',
      wh_id: WH,
      created_at: new Date(),
      audience_roles: ['admin', 'manajer', 'viewer'],
    });
    for (const c of ['daily_data', 'model_health', 'model_health_history', 'batch_logs', 'dataset_status', 'warehouses']) {
      await setDoc(doc(fs, c, WH), { wh_id: WH });
    }
  });
});

describe('unauthenticated', () => {
  test('cannot read predictions', async () => {
    await assertFails(getDoc(doc(anon(), 'predictions', PRED)));
  });
  test('cannot read model_health', async () => {
    await assertFails(getDoc(doc(anon(), 'model_health', WH)));
  });
});

describe('predictions', () => {
  for (const role of ROLES) {
    test(`${role} can read`, async () => {
      await assertSucceeds(getDoc(doc(db(role), 'predictions', PRED)));
    });
    test(`${role} cannot create or delete`, async () => {
      await assertFails(setDoc(doc(db(role), 'predictions', 'pred_new'), { wh_id: WH }));
      await assertFails(deleteDoc(doc(db(role), 'predictions', PRED)));
    });
  }
  for (const role of ['admin', 'supervisor']) {
    test(`${role} can update actual_* fields`, async () => {
      await assertSucceeds(updateDoc(doc(db(role), 'predictions', PRED), actualUpdate(role)));
    });
    test(`${role} cannot write a negative actual`, async () => {
      await assertFails(updateDoc(doc(db(role), 'predictions', PRED), actualUpdate(role, -500)));
    });
    test(`${role} cannot write a non-integer actual`, async () => {
      await assertFails(updateDoc(doc(db(role), 'predictions', PRED), actualUpdate(role, 17560.5)));
    });
    test(`${role} cannot change predicted`, async () => {
      await assertFails(updateDoc(doc(db(role), 'predictions', PRED), { ...actualUpdate(role), predicted: 1 }));
    });
    test(`${role} cannot impersonate actual_input_by`, async () => {
      await assertFails(
        updateDoc(doc(db(role), 'predictions', PRED), { ...actualUpdate(role), actual_input_by: 'someone-else' }),
      );
    });
  }
  for (const role of ['manajer', 'viewer']) {
    test(`${role} cannot update actual`, async () => {
      await assertFails(updateDoc(doc(db(role), 'predictions', PRED), actualUpdate(role)));
    });
  }
});

describe('operational_configs', () => {
  for (const role of ROLES) {
    test(`${role} can read`, async () => {
      await assertSucceeds(getDoc(doc(db(role), 'operational_configs', WH)));
    });
  }
  for (const role of ['admin', 'manajer']) {
    test(`${role} can update with valid values`, async () => {
      await assertSucceeds(updateDoc(doc(db(role), 'operational_configs', WH), validConfig(role)));
    });
    test(`${role} cannot set capacity <= 0`, async () => {
      await assertFails(updateDoc(doc(db(role), 'operational_configs', WH), { ...validConfig(role), capacity_rider: 0 }));
    });
    test(`${role} cannot set ratios not summing to 1.00`, async () => {
      await assertFails(updateDoc(doc(db(role), 'operational_configs', WH), { ...validConfig(role), ratio_rider: 0.75 }));
    });
    test(`${role} cannot delete`, async () => {
      await assertFails(deleteDoc(doc(db(role), 'operational_configs', WH)));
    });
  }
  for (const role of ['supervisor', 'viewer']) {
    test(`${role} cannot update`, async () => {
      await assertFails(updateDoc(doc(db(role), 'operational_configs', WH), validConfig(role)));
    });
  }
});

describe('decision_logs (append-only)', () => {
  for (const role of ['admin', 'manajer', 'supervisor']) {
    test(`${role} can read`, async () => {
      await assertSucceeds(getDoc(doc(db(role), 'decision_logs', 'd1')));
    });
  }
  test('viewer cannot read', async () => {
    await assertFails(getDoc(doc(db('viewer'), 'decision_logs', 'd1')));
  });
  for (const role of ['admin', 'manajer']) {
    test(`${role} can create an approval`, async () => {
      await assertSucceeds(addDoc(collection(db(role), 'decision_logs'), decision(role)));
    });
    test(`${role} can create an adjustment with reason`, async () => {
      await assertSucceeds(
        addDoc(collection(db(role), 'decision_logs'), decision(role, { decision: 'adjusted', reason: 'antrean' })),
      );
    });
    test(`${role} cannot create an adjustment without reason`, async () => {
      await assertFails(addDoc(collection(db(role), 'decision_logs'), decision(role, { decision: 'adjusted', reason: '' })));
    });
    test(`${role} cannot log on behalf of another user`, async () => {
      await assertFails(addDoc(collection(db(role), 'decision_logs'), decision(role, { decided_by: 'uid-other' })));
    });
    test(`${role} cannot update or delete`, async () => {
      await assertFails(updateDoc(doc(db(role), 'decision_logs', 'd1'), { reason: 'x' }));
      await assertFails(deleteDoc(doc(db(role), 'decision_logs', 'd1')));
    });
  }
  for (const role of ['supervisor', 'viewer']) {
    test(`${role} cannot create`, async () => {
      await assertFails(addDoc(collection(db(role), 'decision_logs'), decision(role)));
    });
  }
});

describe('config_history (append-only)', () => {
  for (const role of ['admin', 'manajer', 'supervisor']) {
    test(`${role} can read`, async () => {
      await assertSucceeds(getDoc(doc(db(role), 'config_history', 'h1')));
    });
  }
  test('viewer cannot read', async () => {
    await assertFails(getDoc(doc(db('viewer'), 'config_history', 'h1')));
  });
  for (const role of ['admin', 'manajer']) {
    test(`${role} can create own entry`, async () => {
      await assertSucceeds(
        addDoc(collection(db(role), 'config_history'), { wh_id: WH, changed_by: `uid-${role}`, changed_at: serverTimestamp() }),
      );
    });
    test(`${role} cannot update or delete`, async () => {
      await assertFails(updateDoc(doc(db(role), 'config_history', 'h1'), { wh_id: 'x' }));
      await assertFails(deleteDoc(doc(db(role), 'config_history', 'h1')));
    });
  }
  for (const role of ['supervisor', 'viewer']) {
    test(`${role} cannot create`, async () => {
      await assertFails(
        addDoc(collection(db(role), 'config_history'), { wh_id: WH, changed_by: `uid-${role}`, changed_at: serverTimestamp() }),
      );
    });
  }
});

describe('notifications', () => {
  for (const role of ['admin', 'manajer', 'viewer']) {
    test(`${role} (in audience) can read and query`, async () => {
      await assertSucceeds(getDoc(doc(db(role), 'notifications', `deviation_${WH}_20261009`)));
      await assertSucceeds(
        getDocs(query(collection(db(role), 'notifications'), where('audience_roles', 'array-contains', role))),
      );
    });
  }
  test('supervisor (not in audience) cannot read', async () => {
    await assertFails(getDoc(doc(db('supervisor'), 'notifications', `deviation_${WH}_20261009`)));
  });
  test('query without role filter is rejected', async () => {
    await assertFails(getDocs(collection(db('admin'), 'notifications')));
  });
  for (const role of ROLES) {
    test(`${role} cannot write`, async () => {
      await assertFails(setDoc(doc(db(role), 'notifications', 'n2'), { audience_roles: [role] }));
    });
  }
});

describe('users & notification_reads', () => {
  for (const role of ROLES) {
    test(`${role} can read own profile but not others`, async () => {
      await assertSucceeds(getDoc(doc(db(role), 'users', `uid-${role}`)));
      const other = ROLES.find((r) => r !== role);
      await assertFails(getDoc(doc(db(role), 'users', `uid-${other}`)));
    });
    test(`${role} cannot change own role`, async () => {
      await assertFails(updateDoc(doc(db(role), 'users', `uid-${role}`), { role: 'admin' }));
    });
    test(`${role} can mark own notification as read`, async () => {
      await assertSucceeds(setDoc(doc(db(role), 'users', `uid-${role}`, 'notification_reads', 'n1'), { read_at: serverTimestamp() }));
    });
    test(`${role} cannot write another user's reads`, async () => {
      const other = ROLES.find((r) => r !== role);
      await assertFails(setDoc(doc(db(role), 'users', `uid-${other}`, 'notification_reads', 'n1'), { read_at: serverTimestamp() }));
    });
  }
});

describe('script-owned collections are read-only', () => {
  const cols = ['daily_data', 'model_health', 'model_health_history', 'batch_logs', 'dataset_status', 'warehouses'];
  for (const c of cols) {
    for (const role of ROLES) {
      test(`${role} can read ${c} but not write`, async () => {
        await assertSucceeds(getDoc(doc(db(role), c, WH)));
        await assertFails(setDoc(doc(db(role), c, WH), { wh_id: 'x' }));
      });
    }
  }
});
