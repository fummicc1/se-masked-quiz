# SE Masked Quiz Server (Cloudflare Workers + D1)

Backend server for SE Masked Quiz app with Sign in with Apple support, built with Hono on Cloudflare Workers and D1 database.

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Create D1 Database

```bash
# Create the database
wrangler d1 create se-masked-quiz-db

# Copy the database_id from the output and update wrangler.toml
```

### 3. Configure wrangler.toml

Update the `database_id` in `wrangler.toml` with the ID from step 2:

```toml
[[d1_databases]]
binding = "DB"
database_name = "se-masked-quiz-db"
database_id = "your-database-id-here"
```

### 4. Create KV Namespace for caching

```bash
# Create KV namespace
wrangler kv:namespace create CACHE

# Copy the id from the output and update wrangler.toml
```

### 5. Generate and run database migrations

```bash
# Generate migration files
npm run db:generate

# Apply migrations locally
npm run db:migrate

# Apply migrations to production
wrangler d1 execute se-masked-quiz-db --file=./migrations/0000_initial.sql
```

### 6. Set secrets

```bash
# Set JWT secret
wrangler secret put JWT_SECRET
# Enter a strong random string when prompted

# Set Apple private key (if needed for advanced features)
wrangler secret put APPLE_PRIVATE_KEY
# Paste the contents of your .p8 file when prompted
```

### 7. Update environment variables

Edit `wrangler.toml` to set your Apple Service ID:

```toml
[vars]
APPLE_SERVICE_ID = "com.example.se-masked-quiz"
```

### 8. Apple Developer Setup

1. Sign in to [Apple Developer](https://developer.apple.com)
2. Go to Identifiers > Service IDs
3. Create a new Service ID for your web service
4. Enable "Sign in with Apple" for the Service ID
5. Configure the redirect URLs if needed

### 9. Run the development server

```bash
npm run dev
```

### 10. Deploy to Cloudflare Workers

```bash
npm run deploy
```

## API Endpoints

### Authentication

- `POST /auth/apple` - Sign in with Apple
  - Body: `{ identityToken, authorizationCode?, user? }`
  - Returns: `{ success, token, user }`

- `GET /auth/me` - Get current user info (requires authentication)
  - Headers: `Authorization: Bearer <token>`
  - Returns: User info

- `POST /auth/verify` - Verify JWT token
  - Headers: `Authorization: Bearer <token>`
  - Returns: `{ success, userId, email? }`

### Health Check

- `GET /health` - Server health check
  - Returns: `{ status: "ok", timestamp, environment }`

## Database Schema

The D1 database uses the following schema:

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT,
  email_verified INTEGER DEFAULT 0,
  is_private_email INTEGER DEFAULT 0,
  real_user_status INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## Development Tips

- Use `wrangler dev --local` for local development with D1
- Use `wrangler tail` to view live logs from your Worker
- The KV cache stores Apple's public keys for 24 hours to improve performance

## Security Notes

- JWT tokens are signed with HS256
- Apple's public keys are cached in KV for performance
- All user data is stored in D1 database
- CORS is enabled for all origins (configure for production)
- Consider implementing rate limiting with Cloudflare's rate limiting features