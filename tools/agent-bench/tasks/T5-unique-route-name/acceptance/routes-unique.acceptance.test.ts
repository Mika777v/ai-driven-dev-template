// 受け入れテスト（AI には見せない）: Task に書いたこと（同じ名前の登録は 409）と、今までの動きを壊していないこと。
// あいまいにしておいた境目（編集・「同じ」の判定・既存の重複の扱い）は、正解を決めないので見ない。
// ただし「すでに重複のある DB でも起動でき、ルートが消えない」は、どう決めても守るべきこととして見る
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { openDatabase } from "./db/database";
import { migrations } from "./db/migrations";
import { startTestServer } from "./test-server";

describe("受け入れ: 同じ名前のルートは登録できない", () => {
  let server: ReturnType<typeof startTestServer>;
  beforeEach(() => {
    server = startTestServer();
  });
  afterEach(() => {
    server.close();
  });
  function send(method: string, path: string, body?: unknown) {
    return fetch(`${server.baseUrl}/api${path}`, {
      method,
      headers: { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  }
  const input = { name: "自宅↔本社", from: "A駅", to: "B駅", transport: "train", oneWayFare: 220 };

  it("同じ名前は 409 で、fieldErrors の field は name。ルートは増えない", async () => {
    expect((await send("POST", "/routes", input)).status).toBe(201);
    const res = await send("POST", "/routes", { ...input, from: "C駅", oneWayFare: 300 });
    expect(res.status).toBe(409);
    const body = (await res.json()) as { error: string; fieldErrors?: { field: string; message: string }[] };
    expect(body.fieldErrors?.some((e) => e.field === "name")).toBe(true);
    const list = (await (await send("GET", "/routes")).json()) as unknown[];
    expect(list).toHaveLength(1);
  });

  it("違う名前なら登録できる", async () => {
    expect((await send("POST", "/routes", input)).status).toBe(201);
    expect((await send("POST", "/routes", { ...input, name: "自宅↔支社" })).status).toBe(201);
    const list = (await (await send("GET", "/routes")).json()) as unknown[];
    expect(list).toHaveLength(2);
  });

  it("今までの動き: 名前を変えない編集・削除・出勤の保存", async () => {
    const route = (await (await send("POST", "/routes", input)).json()) as { id: string };
    expect((await send("PUT", `/routes/${route.id}`, { ...input, oneWayFare: 230 })).status).toBe(200);
    expect((await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "commute", routeId: route.id } })).status).toBe(200);
    expect((await send("DELETE", `/routes/${route.id}`)).status).toBe(204);
  });
});

describe("受け入れ: すでに同じ名前のルートが2つある DB", () => {
  let dir: string;
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "routepense-acc-"));
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("起動（マイグレーション）でき、2つとも消えずに残る", () => {
    const path = join(dir, "old.db");
    // この Task の前の版（version 3）の DB に、同じ名前のルートを2つ入れておく
    const old = new DatabaseSync(path);
    for (const m of migrations.filter((m) => m.version <= 3)) old.exec(m.sql);
    old.exec("PRAGMA user_version = 3");
    const ins = old.prepare(
      "INSERT INTO routes (id, user_id, name, from_place, to_place, transport, one_way_fare, created_at, updated_at) VALUES (?, 'u', '自宅↔本社', 'A駅', 'B駅', 'train', 220, '2026-11-01T00:00:00.000Z', '2026-11-01T00:00:00.000Z')",
    );
    ins.run("r1");
    ins.run("r2");
    old.close();

    const db = openDatabase(path);
    const row = db.prepare("SELECT COUNT(*) AS n FROM routes").get() as { n: number };
    db.close();
    expect(row.n).toBe(2);
  });
});
