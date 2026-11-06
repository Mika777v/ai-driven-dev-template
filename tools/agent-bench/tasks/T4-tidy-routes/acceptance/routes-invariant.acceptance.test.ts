// 受け入れテスト（AI には見せない）: 曖昧な Task なので、正解の形は決めない。
// 今までの動き（ルートの登録・一覧・出勤の保存、ルートを消しても記録の値は残る）を壊していないかだけを見る
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { startTestServer } from "./test-server";

describe("受け入れ: 今までのルートの動きを壊していない", () => {
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

  it("ルートを登録すると一覧に出る", async () => {
    expect((await send("POST", "/routes", input)).status).toBe(201);
    const list = (await (await send("GET", "/routes")).json()) as { name: string }[];
    expect(list.map((r) => r.name)).toContain("自宅↔本社");
  });

  it("登録したルートで出勤を保存できる", async () => {
    const route = (await (await send("POST", "/routes", input)).json()) as { id: string };
    expect((await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "commute", routeId: route.id } })).status).toBe(200);
  });

  it("ルートを削除しても、そのルートで保存した記録の値は残る", async () => {
    const route = (await (await send("POST", "/routes", input)).json()) as { id: string };
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "commute", routeId: route.id } });
    expect((await send("DELETE", `/routes/${route.id}`)).status).toBe(204);
    const list = (await (await send("GET", "/daily-records?month=2026-11")).json()) as { workStyle: { route?: { name: string } } }[];
    expect(list[0]?.workStyle.route?.name).toBe("自宅↔本社");
  });
});
