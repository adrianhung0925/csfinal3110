import net from "node:net";
import { StringDecoder } from "node:string_decoder";
import { WebSocket, WebSocketServer } from "ws";

function readPort(name, fallback) {
  const value = process.env[name];
  if (value === undefined) {
    if (fallback !== undefined) return fallback;
    throw new Error(`${name} must be set to a port from 1 to 65535`);
  }

  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`${name} must be an integer port from 1 to 65535`);
  }
  return port;
}

const websocketHost = process.env.WS_HOST ?? "127.0.0.1";
const websocketPort = readPort("WS_PORT", 9001);
const tcpHost = process.env.TCP_HOST ?? "127.0.0.1";
const tcpPort = readPort("TCP_PORT");
const maxPayload = 1024 * 1024;
const websocketServer = new WebSocketServer({
  host: websocketHost,
  port: websocketPort,
  maxPayload,
});

websocketServer.on("listening", () => {
  console.log(
    `WebSocket gateway listening on ws://${websocketHost}:${websocketPort} -> ${tcpHost}:${tcpPort}`,
  );
});

websocketServer.on("connection", (websocket) => {
  let tcpSocket;
  let tcpReady = false;
  let pendingTcpLines = [];
  let tcpBuffer = "";
  const decoder = new StringDecoder("utf8");

  const closeWebSocket = (code, reason) => {
    if (websocket.readyState === WebSocket.OPEN) {
      websocket.close(code, reason);
    } else if (websocket.readyState === WebSocket.CONNECTING) {
      websocket.terminate();
    }
  };

  const sendTcpLine = (line) => {
    if (websocket.readyState === WebSocket.OPEN) {
      websocket.send(line);
    }
    if (line.startsWith("ID_REJECTED:")) {
      closeWebSocket(1008, "Client ID rejected");
      tcpSocket?.end();
    }
  };

  const handleTcpData = (chunk) => {
    tcpBuffer += decoder.write(chunk);
    if (tcpBuffer.length > maxPayload && !tcpBuffer.includes("\n")) {
      closeWebSocket(1009, "Server message is too large");
      tcpSocket.destroy();
      return;
    }

    let newlineIndex;
    while ((newlineIndex = tcpBuffer.indexOf("\n")) !== -1) {
      let line = tcpBuffer.slice(0, newlineIndex);
      tcpBuffer = tcpBuffer.slice(newlineIndex + 1);
      if (line.endsWith("\r")) line = line.slice(0, -1);
      sendTcpLine(line);
    }
  };

  websocket.on("message", (data, isBinary) => {
    if (isBinary) {
      closeWebSocket(1003, "Text messages are required");
      return;
    }

    const line = data.toString();
    if (line.includes("\n") || line.includes("\r")) {
      closeWebSocket(1008, "Each message must be one protocol line");
      return;
    }

    if (!tcpSocket) {
      pendingTcpLines.push(line);
      tcpSocket = net.createConnection({ host: tcpHost, port: tcpPort });
      tcpSocket.setNoDelay(true);
      tcpSocket.on("connect", () => {
        tcpReady = true;
        for (const pendingLine of pendingTcpLines) {
          if (tcpSocket.destroyed) break;
          tcpSocket.write(`${pendingLine}\n`);
        }
        pendingTcpLines = [];
      });
      tcpSocket.on("data", handleTcpData);
      tcpSocket.on("end", () => {
        const finalLine = decoder.end();
        if (finalLine.length > 0) tcpBuffer += finalLine;
        if (tcpBuffer.length > 0) sendTcpLine(tcpBuffer);
      });
      tcpSocket.on("error", (error) => {
        console.error(`TCP connection error: ${error.message}`);
        closeWebSocket(1011, "Could not connect to the TCP server");
      });
      tcpSocket.on("close", () => {
        if (websocket.readyState === WebSocket.OPEN) {
          websocket.close(1000, "TCP connection closed");
        }
      });
      return;
    }

    if (!tcpReady) {
      pendingTcpLines.push(line);
      return;
    }

    if (!tcpSocket.destroyed) tcpSocket.write(`${line}\n`);
  });

  websocket.on("close", () => {
    tcpSocket?.destroy();
  });
  websocket.on("error", (error) => {
    console.error(`WebSocket connection error: ${error.message}`);
    tcpSocket?.destroy();
  });
});

websocketServer.on("error", (error) => {
  console.error(`WebSocket gateway error: ${error.message}`);
  process.exitCode = 1;
});
