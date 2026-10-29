import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {canTransition,price} from './policy';
test('work requires identity verification',()=>{assert.equal(canTransition('arrived','in_progress'),false);assert.equal(canTransition('identity_verified','in_progress'),true);});
test('terminal status cannot reopen',()=>{assert.equal(canTransition('completed','requested'),false);});
test('price is calculated with bounded integer amounts',()=>{assert.equal(price(300,600,450),1350);assert.throws(()=>price(300,-1,450));assert.throws(()=>price(300,1.5,0));});
