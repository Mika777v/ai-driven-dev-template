// 受け入れテスト（AI には見せない。作業が終わった後に backend/src/db/ に置いて流す）
// 前の版（マイグレーション 3 まで）の DB にデータを入れておき、新しい版で開いてもデータが残ることを確かめる
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { openDatabase } from "./database";
import { migrations } from "./migrations";

describe("受け入れ: タクシーを足しても、前の版のデータが残る", () => {
  let dir: string;
  let file: string;
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "routepense-accept-"));
    file = join(dir, "old.db");
    // 前の版の DB（マイグレーション 3 まで）を作り、データを入れる
    const old = new DatabaseSync(file);
    old.exec("PRAGMA foreign_keys = ON");
    for (const m of migrations.filter((x) => x.version <= 3)) old.exec(m.sql);
    old.exec("PRAGMA user_version = 3");
    const at = "2026-11-01T00:00:00.000Z";
    old.prepare("INSERT INTO routes (id, user_id, name, from_place, to_place, transport, one_way_fare, created_at, updated_at, search_url) VALUES (?,?,?,?,?,?,?,?,?,?)")
      .run("r1", "u1", "自宅↔本社", "A駅", "B駅", "train", 220, at, at, "https://example.invalid/route");
    old.prepare("INSERT INTO daily_records (id, user_id, date, work_kind, route_id, route_name, route_from, route_to, route_transport, route_one_way_fare, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)")
      .run("d1", "u1", "2026-11-02", "commute", "r1", "自宅↔本社", "A駅", "B駅", "bus", 220, at, at);
    old.prepare("INSERT INTO daily_records (id, user_id, date, work_kind, created_at, updated_at) VALUES (?,?,?,?,?,?)")
      .run("d2", "u1", "2026-11-03", "remote", at, at);
    old.prepare("INSERT INTO extra_trips (id, daily_record_id, from_place, to_place, transport, one_way_fare, trip_type, purpose, source_route_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)")
      .run("t1", "d1", "B駅", "C駅", "other", 160, "roundTrip", "客先A", null, at);
    old.prepare("INSERT INTO extra_trips (id, daily_record_id, from_place, to_place, transport, one_way_fare, trip_type, purpose, source_route_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)")
      .run("t2", "d2", "自宅", "D駅", "train", 300, "oneWay", null, "r1", at);
    old.close();
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("ルート・日次記録・追加の移動が、全部の列ごと残る", () => {
    const db = openDatabase(file);
    try {
      expect(db.prepare("SELECT id, name, transport, one_way_fare, search_url FROM routes").all()).toEqual([
        { id: "r1", name: "自宅↔本社", transport: "train", one_way_fare: 220, search_url: "https://example.invalid/route" },
      ]);
      expect(db.prepare("SELECT id, date, work_kind, route_transport FROM daily_records ORDER BY date").all()).toEqual([
        { id: "d1", date: "2026-11-02", work_kind: "commute", route_transport: "bus" },
        { id: "d2", date: "2026-11-03", work_kind: "remote", route_transport: null },
      ]);
      expect(db.prepare("SELECT id, daily_record_id, transport, purpose, source_route_id FROM extra_trips ORDER BY id").all()).toEqual([
        { id: "t1", daily_record_id: "d1", transport: "other", purpose: "客先A", source_route_id: null },
        { id: "t2", daily_record_id: "d2", transport: "train", purpose: null, source_route_id: "r1" },
      ]);
    } finally {
      db.close();
    }
  });

  it("新しい版では、3つのテーブルのどれにもタクシーを入れられる", () => {
    const db = openDatabase(file);
    try {
      const at = "2026-11-05T00:00:00.000Z";
      db.prepare("INSERT INTO routes (id, user_id, name, from_place, to_place, transport, one_way_fare, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?)")
        .run("r2", "u1", "駅↔客先", "C駅", "客先", "taxi", 1200, at, at);
      db.prepare("INSERT INTO daily_records (id, user_id, date, work_kind, route_id, route_name, route_from, route_to, route_transport, route_one_way_fare, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)")
        .run("d3", "u1", "2026-11-04", "commute", "r2", "駅↔客先", "C駅", "客先", "taxi", 1200, at, at);
      db.prepare("INSERT INTO extra_trips (id, daily_record_id, from_place, to_place, transport, one_way_fare, trip_type, created_at) VALUES (?,?,?,?,?,?,?,?)")
        .run("t3", "d3", "客先", "C駅", "taxi", 1200, "oneWay", at);
      expect((db.prepare("SELECT COUNT(*) AS n FROM extra_trips WHERE transport = 'taxi'").get() as { n: number }).n).toBe(1);
    } finally {
      db.close();
    }
  });

  it("今までの制約は残る（一覧に無い値は入らない・日次記録を消すと追加の移動も消える）", () => {
    const db = openDatabase(file);
    try {
      const at = "2026-11-05T00:00:00.000Z";
      expect(() =>
        db.prepare("INSERT INTO routes (id, user_id, name, from_place, to_place, transport, one_way_fare, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?)")
          .run("r9", "u1", "x", "x", "x", "plane", 1, at, at),
      ).toThrow();
      expect(db.prepare("PRAGMA foreign_key_check").all()).toEqual([]);
      db.prepare("DELETE FROM daily_records WHERE id = ?").run("d1");
      expect(db.prepare("SELECT id FROM extra_trips ORDER BY id").all()).toEqual([{ id: "t2" }]);
    } finally {
      db.close();
    }
  });
});
