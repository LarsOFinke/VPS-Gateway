# Testing

```bash
make test
make check-tree
make validate
```

The gate checks anonymization, versioning, repository structure, shell syntax,
ShellCheck when installed, and whitespace errors.

On a disposable Debian/Ubuntu server, additionally verify that `setup.sh` keeps
existing site files, `nginx -t` passes, and the service remains active. Project
repositories must test their own site files and loopback upstreams.
