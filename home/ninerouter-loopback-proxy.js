"use strict";

const net = require("net");

const listenPort = Number(process.env.NINEROUTER_PUBLISH_PORT || 20128);
const destPort = Number(process.env.PORT || 20129);
const destHost = process.env.HOSTNAME || "127.0.0.1";

const server = net.createServer((client) => {
  const upstream = net.connect({ host: destHost, port: destPort }, () => {
    client.pipe(upstream);
    upstream.pipe(client);
  });
  const fail = () => {
    client.destroy();
    upstream.destroy();
  };
  upstream.on("error", fail);
  client.on("error", fail);
});

server.on("error", (err) => {
  console.error("ninerouter-loopback-proxy:", err.message);
  process.exit(1);
});

server.listen(listenPort, "0.0.0.0", () => {
  console.log(
    `ninerouter-loopback-proxy: 0.0.0.0:${listenPort} -> ${destHost}:${destPort}`,
  );
});
