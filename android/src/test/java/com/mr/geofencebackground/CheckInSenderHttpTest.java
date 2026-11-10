package com.mr.geofencebackground;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

/** Sends real HTTP requests to a small local server to check what CheckInSender does with each answer. */
public class CheckInSenderHttpTest {

    private ServerSocket serverSocket;
    private Thread serverThread;
    private final AtomicInteger nextStatus = new AtomicInteger(200);
    private final List<String> receivedBodies = new CopyOnWriteArrayList<>();

    @Before
    public void startServer() throws IOException {
        serverSocket = new ServerSocket(0, 10, InetAddress.getLoopbackAddress());
        serverThread = new Thread(() -> {
            while (!serverSocket.isClosed()) {
                try (Socket socket = serverSocket.accept()) {
                    receivedBodies.add(readRequestBody(socket.getInputStream()));
                    int status = nextStatus.get();
                    String reply = "HTTP/1.1 " + status + " Test\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok";
                    OutputStream out = socket.getOutputStream();
                    out.write(reply.getBytes(StandardCharsets.US_ASCII));
                    out.flush();
                } catch (IOException e) {
                    // Server closed.
                }
            }
        });
        serverThread.start();
    }

    @After
    public void stopServer() throws Exception {
        serverSocket.close();
        serverThread.join(2000);
    }

    @Test
    public void serverErrorIsRetriedThenAccepted() {
        nextStatus.set(503);
        assertEquals(CheckInSender.Outcome.RETRY, CheckInSender.send(request(endpoint())));

        nextStatus.set(200);
        assertEquals(CheckInSender.Outcome.SENT, CheckInSender.send(request(endpoint())));

        assertEquals(2, receivedBodies.size());
        assertTrue(receivedBodies.get(1).contains("name=\"event_id\"\r\n\r\nevent-1\r\n"));
        assertTrue(receivedBodies.get(1).contains("name=\"checkin\"\r\n\r\ntrue\r\n"));
    }

    @Test
    public void rejectedRequestIsDropped() {
        nextStatus.set(401);
        assertEquals(CheckInSender.Outcome.DROP, CheckInSender.send(request(endpoint())));
    }

    @Test
    public void noServerIsRetried() throws IOException {
        int closedPort;
        try (ServerSocket unused = new ServerSocket(0, 1, InetAddress.getLoopbackAddress())) {
            closedPort = unused.getLocalPort();
        }
        assertEquals(CheckInSender.Outcome.RETRY, CheckInSender.send(request("http://127.0.0.1:" + closedPort + "/attendance")));
    }

    @Test
    public void invalidEndpointIsDropped() {
        assertEquals(CheckInSender.Outcome.DROP, CheckInSender.send(request("not a url")));
    }

    private String endpoint() {
        return "http://127.0.0.1:" + serverSocket.getLocalPort() + "/attendance";
    }

    private static CheckInRequest request(String endpoint) {
        return new CheckInRequest("event-1", endpoint, "token-1", 42, 24.8607, 67.0011, true, 1794301333000L);
    }

    /** Reads an HTTP request and returns its body (the plugin always sends Content-Length). */
    private static String readRequestBody(InputStream in) throws IOException {
        ByteArrayOutputStream headers = new ByteArrayOutputStream();
        int matched = 0;
        byte[] end = { '\r', '\n', '\r', '\n' };
        while (matched < end.length) {
            int b = in.read();
            if (b < 0) {
                return "";
            }
            headers.write(b);
            matched = b == end[matched] ? matched + 1 : (b == end[0] ? 1 : 0);
        }
        int length = 0;
        for (String line : headers.toString("US-ASCII").split("\r\n")) {
            if (line.toLowerCase(Locale.ROOT).startsWith("content-length:")) {
                length = Integer.parseInt(line.substring("content-length:".length()).trim());
            }
        }
        byte[] body = new byte[length];
        int read = 0;
        while (read < length) {
            int n = in.read(body, read, length - read);
            if (n < 0) {
                break;
            }
            read += n;
        }
        return new String(body, 0, read, StandardCharsets.UTF_8);
    }
}
