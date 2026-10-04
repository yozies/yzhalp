import { test } from "node:test";
import assert from "node:assert/strict";
import { delta } from "../js/WheelScroll.mjs";
import { normalize } from "../js/Preferences.mjs";

test("touchpad pixel deltas take precedence over angle fallback and retain both axes", () => {
    assert.deepEqual(delta({ x: -6, y: -18 }, { x: -120, y: -120 }, 3), { x: 6, y: 18 });
    assert.deepEqual(delta({ x: 6, y: 18 }, { x: 120, y: 120 }, 3), { x: -6, y: -18 });
});

test("fine wheel events preserve subpixel movement and honor system scroll lines", () => {
    assert.equal(delta({ x: 0, y: 0 }, { x: 0, y: -1 }, 3).y, 0.6);
    assert.equal(delta({ x: 0, y: 0 }, { x: 0, y: -120 }, 5).y, 120);
    assert.equal(delta({ x: 0, y: 0 }, { x: 0, y: -120 }, 0).y, 0);
});

test("the optional speed multiplier and Shift pan also work with precise pixel input", () => {
    assert.deepEqual(delta({ x: 0, y: -20 }, { x: 0, y: -120 }, 3, 2, true), { x: 40, y: 0 });
    assert.deepEqual(delta({ x: -3, y: -20 }, { x: 0, y: -120 }, 3, 1, true), { x: 3, y: 20 });
    assert.equal(delta({ x: 0, y: 0 }, { x: 0, y: -120 }, 3, 0.5).y, 36);
});

test("scroll speed defaults to system-relative 100% and validates saved values", () => {
    assert.equal(normalize({}, "/home/me").scrollSpeed, 1);
    assert.equal(normalize({ scrollSpeed: "fast" }, "/home/me").scrollSpeed, 1);
    assert.equal(normalize({ scrollSpeed: -1 }, "/home/me").scrollSpeed, 0.25);
    assert.equal(normalize({ scrollSpeed: 50 }, "/home/me").scrollSpeed, 4);
});
