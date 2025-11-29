# SSL Test Infrastructure

## Description

Set up proper SSL/TLS testing infrastructure so that SSL-related tests can run reliably. This includes configuring the inspircd Docker container with SSL certificates and ensuring tests can connect over TLS.

## Behavior

### Container Configuration

1. Create or configure inspircd container with SSL enabled on port 6697
2. Generate self-signed certificates for testing
3. Mount certificates into the container
4. Update `bin/start-irc-server` to set up SSL-enabled container

### Test Updates

1. Remove skip logic from SSL tests in `test/integration/socket_test.rb`
2. SSL tests should run and pass reliably
3. Verify both SSL connection and read/write operations work

## Tests

**SSL connection succeeds**
- Given: inspircd with SSL on localhost:6697
- When: Connect with ssl: true, verify_mode: VERIFY_NONE
- Then: Connection established, state is :connecting

**SSL read/write works**
- Given: SSL connection established
- When: Send NICK/USER commands
- Then: Receive server responses

**SSL certificate verification**
- Given: Self-signed cert on server
- When: Connect with VERIFY_PEER
- Then: Fails unless cert is trusted
- When: Connect with VERIFY_NONE
- Then: Succeeds

## Implementation Notes

- Use OpenSSL to generate self-signed certs: `openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes`
- Store certs in `test/fixtures/ssl/` or similar
- May need custom inspircd.conf to enable SSL module
- Update `bin/stop-irc-server` if container setup changes

## Dependencies

- Requires `02-connection-socket.md` to be complete (SSL support in Socket class)
