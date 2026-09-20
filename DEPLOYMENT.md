# Deploying the Bakeshop Backend to EC2 with Docker + GitHub Actions

Workflow: `Developer → git push → GitHub Actions (build) → GHCR (store image) → EC2 (run containers)`

## What was missing / added

- `backend/Dockerfile` — builds the Node app into an image
- `backend/.dockerignore` — keeps `node_modules`/`.env` out of the build
- `docker-compose.yml` — runs the backend + MySQL together on EC2
- `.env.example` — template for the secrets docker-compose needs
- `.gitignore` — keeps `node_modules`/`.env` out of git
- `.github/workflows/deploy.yml` — the CI/CD pipeline itself
- `backend/server.js` — updated so DB credentials come from environment
  variables instead of the hardcoded `localhost`/`root`/empty-password
  values (those only worked when MySQL was installed directly on your
  laptop; a container needs to reach a *different* host)

Your original files (`server.js`, `init.sql`, `package.json`) are otherwise
unchanged in logic — only the DB connection block and `app.listen` line
were updated.

---

## Step 1 — Push the project to GitHub

```bash
cd backend-project        # the folder containing backend/, docker-compose.yml, etc.
git init
git add .
git commit -m "Initial commit: bakeshop backend"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

Make sure `.env` is **not** committed (it's in `.gitignore`) — only
`.env.example` should be in the repo.

## Step 2 — Nothing extra to "deploy at git" — pushing to `main` is the trigger

Once `.github/workflows/deploy.yml` is in the repo, every push to `main`
will run automatically. But don't push yet — first set up EC2 and the
secrets below, or the deploy step will fail with nothing to SSH into.

## Step 3 — Set up EC2 (AWS Free Tier)

1. AWS Console → EC2 → **Launch instance**
2. AMI: **Ubuntu Server 22.04 LTS** (free-tier eligible)
3. Instance type: **t2.micro** (or `t3.micro`, whichever your account's
   free tier offers)
4. Create/select a key pair (`.pem`) — download it, you'll need it for SSH
5. Network settings → Edit security group, add inbound rules:
   - SSH (22) — Source: **My IP** (safer than 0.0.0.0/0)
   - Custom TCP (3000) — Source: **0.0.0.0/0** (so the API is reachable)
   - Leave 80/443 out for now unless you plan to add Nginx + a domain later
6. Launch, then note the instance's **public IPv4 address**

Connect to confirm it works:
```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

## Step 4 — Install Docker on EC2 and prepare the deploy folder

Run on the EC2 instance (via SSH):

```bash
# Install Docker Engine + Compose plugin
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Let your user run docker without sudo
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

Create the deploy folder and copy in `docker-compose.yml`, `.env`, and
`backend/init.sql` (these are the only files EC2 needs — the backend
*image* itself comes from GHCR, not from source):

```bash
mkdir -p ~/bakeshop-app/backend
exit   # back to your laptop
```

From your laptop:
```bash
scp -i your-key.pem docker-compose.yml ubuntu@<EC2_PUBLIC_IP>:~/bakeshop-app/
scp -i your-key.pem backend/init.sql ubuntu@<EC2_PUBLIC_IP>:~/bakeshop-app/backend/
```

Back on EC2, create the real `.env` (never commit this one):
```bash
cd ~/bakeshop-app
nano .env
```
```
DB_NAME=bakeshop
DB_ROOT_PASSWORD=<pick a strong password>
GHCR_OWNER=<your-github-username-lowercase>
GHCR_IMAGE=backend
```

### "Connect EC2 with git" — you don't need git on EC2 at all

Since the pipeline builds the image in GitHub Actions and pushes it to
GHCR, EC2 never needs to clone your repo or have git installed — it only
needs `docker compose pull` + `docker compose up -d`. This is simpler and
more secure than pulling source and building on the server.

## Step 5 — Create a GHCR Pull token and add GitHub Secrets

EC2 needs to authenticate to GHCR to pull a **private** package. Create a
Personal Access Token:

1. GitHub → Settings → Developer settings → **Personal access tokens**
   → Tokens (classic) → Generate new token
2. Scope: `read:packages` only
3. Copy the token

Then, in your repo → Settings → Secrets and variables → Actions, add:

| Secret         | Value                                            |
|----------------|---------------------------------------------------|
| `EC2_HOST`     | EC2 public IP                                     |
| `EC2_USER`     | `ubuntu`                                          |
| `EC2_SSH_KEY`  | full contents of your `.pem` private key          |
| `GHCR_PAT`     | the `read:packages` token above                   |

(`GITHUB_TOKEN` used for the *push* to GHCR is automatic — you don't add it yourself.)

## Step 6 — First manual deployment (do this once, before trusting CI/CD)

This proves the image and compose file actually work before you wire up
automation.

On your laptop, build and push the image once by hand (you said Docker
isn't installed locally — this is the one step where you need it, or you
can skip straight to letting GitHub Actions build it by pushing to `main`
and watching the Actions tab). If you do have access to another machine
with Docker:

```bash
docker build -t ghcr.io/<owner>/backend:latest ./backend
docker login ghcr.io -u <owner>
docker push ghcr.io/<owner>/backend:latest
```

Then on EC2:
```bash
cd ~/bakeshop-app
echo "<GHCR_PAT>" | docker login ghcr.io -u <owner> --password-stdin
docker compose pull backend
docker compose up -d
docker compose ps
curl http://localhost:3000/health
```

If `curl` returns `{"status":"ok"}`, it's working. Test from your laptop
browser too: `http://<EC2_PUBLIC_IP>:3000/health`.

## Step 7 — Let CI/CD take over

Now just push to `main`:
```bash
git add .
git commit -m "Add Docker + CI/CD"
git push
```

Watch the **Actions** tab in GitHub — it will build the image, push it to
GHCR, then SSH into EC2 and redeploy automatically. Every future push to
`main` repeats this with zero manual steps.

## Troubleshooting notes

- **Image name must be lowercase.** If your GitHub username/org has
  capital letters, set `GHCR_OWNER` in `.env` to the lowercase form —
  GHCR rejects uppercase image paths.
- **First run only:** `init.sql` seeds the database only when the MySQL
  volume is empty. If you need to reset data, `docker compose down -v`
  wipes the `db_data` volume (do this before re-seeding, never in a real
  production dataset).
- **Logs:** `docker compose logs -f backend` and `docker compose logs -f db`
  on EC2 are your first stop for any failure.
- **Free tier limits:** `t2.micro` has 1 GB RAM — MySQL + Node together
  is fine for a small app/demo but watch `docker stats` if it gets slow.
- **Next hardening step (optional, not required to make this work):**
  put Nginx + Let's Encrypt in front of port 3000 for HTTPS and a real
  domain, and move MySQL to RDS free tier instead of a container once you
  outgrow this setup.
