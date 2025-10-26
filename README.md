# NixOS

If you're making a lot of changes, skip the cache by adding the `--refresh` flag.

## Tasks

### hetzner-dedicated-x86_64-switch

```bash
sudo nixos-rebuild switch --flake github:a-h/nixos#hetzner-dedicated-x86_64 --refresh
```

### hetzner-builder-x86_64-switch

```bash
sudo nixos-rebuild switch --flake github:a-h/nixos#hetzner-builder-x86_64 --refresh
```

### nixos-switch-aarch64

```
sudo nixos-rebuild switch --flake github:a-h/nixos#builder-aarch64
```

### nixos-switch-aarch64-local

```bash
sudo nixos-rebuild switch --flake .#nixos-aarch64
```

### start

See https://ryan.himmelwright.net/post/utmctl-nearly-headless-vms/

```bash
utmctl start aarch64
utmctl start aarch64
```

### minio-login

Inputs: ACCESS_KEY, SECRET_KEY

```bash
mc alias set minio-adrianhesketh-com https://minio.adrianhesketh.com $ACCESS_KEY $SECRET_KEY
```

### minio-nix-cache-bucket-create

```bash
mc mb minio-adrianhesketh-com/nix-cache
```

### minio-nix-cache-user-create

Inputs: ACCESS_KEY, SECRET_KEY

```bash
mc admin user add minio-adrianhesketh-com $ACCESS_KEY $SECRET_KEY
```

### minio-nix-cache-create-read-write-user

Inputs: ACCESS_KEY

```bash
# Create policy.
mc admin policy create minio-adrianhesketh-com nix-cache-read-write-policy ./minio/nix-cache-read-write-policy.json
# Create group and attach policy.
mc admin group add minio-adrianhesketh-com nix-cache-read-write $ACCESS_KEY
mc admin policy attach minio-adrianhesketh-com nix-cache-read-write-policy --group=nix-cache-read-write
```

### minio-nix-cache-create-read-user

Inputs: ACCESS_KEY

```bash
# Create policy.
mc admin policy create minio-adrianhesketh-com nix-cache-read-policy ./minio/nix-cache-read-policy.json
# Create group and attach policy.
mc admin group add minio-adrianhesketh-com nix-cache-read $ACCESS_KEY
mc admin policy attach minio-adrianhesketh-com nix-cache-read-policy --group=nix-cache-read
```

### minio-nix-cache-setup-cli

Inputs: ACCESS_KEY, SECRET_KEY

To set up the AWS CLI to use your new MinIO server, you must configure the AWS CLI.

```bash
cat <<EOF > ~/.aws/config
[profile minio-adrianhesketh-com]
region = us-east-1
output = json
# The endpoint is the URL of the MinIO server, but this is, sadly, ignored by the Nix tools, and you have to specify it in the store path.
endpoint_url = https://minio.adrianhesketh.com
EOF
cat <<EOF > ~/.aws/credentials
[minio-adrianhesketh-com]
aws_access_key_id=$ACCESS_KEY
aws_secret_access_key=$SECRET_KEY
EOF
```

### minio-list-buckets

With the AWS CLI configured to use the MinIO server, you can list the buckets using the AWS CLI instead.

```bash
aws s3 --profile minio-adrianhesketh-com ls
```

### minio-nix-cache-list-bucket

```bash
aws s3 --profile minio-adrianhesketh-com ls s3://nix-cache
```

### minio-nix-cache-test-cp

```bash
aws s3 --profile minio-adrianhesketh-com cp ./README.md s3://nix-cache/README.md
```

### minio-nix-cache-ping

Add `-vvvv` for verbose output.

```bash
nix store info --store 's3://nix-cache?profile=minio-adrianhesketh-com&endpoint=minio.adrianhesketh.com'
```

### minio-nix-cache-push

Add `-vvvv` for verbose output.

```bash
pass minio.adrianhesketh.com/nix-store-private-key.pem > ~/nix-store-private-key.pem
nix copy --to 's3://nix-cache?profile=minio-adrianhesketh-com&endpoint=minio.adrianhesketh.com' .#devShells.x86_64-linux.default
nix store sign -k ~/nix-store-private-key.pem --store 's3://nix-cache?profile=minio-adrianhesketh-com&endpoint=minio.adrianhesketh.com' .#devShells.x86_64-linux.default
```

It's also possible to copy `nix copy --to 's3://nix-cache?profile=minio-adrianhesketh-com&endpoint=minio.adrianhesketh.com' .#devShells.x86_64-linux.default` and then sign the store path.

## Goals

Everything required to self-host a development and deployment environment.

- Source control
- CI/CD
- Hypervisor
- Kubernetes
- Observability
- Storage
- Networking
- Access control
- Security
  - Secrets management
  - Encryption
  - Authentication and authorization
- Backup

