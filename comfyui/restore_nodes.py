"""
Restore user-installed custom nodes via symlinks + snapshot.

1. Symlink user_nodes/* -> custom_nodes/* (persistent user nodes)
2. Migrate non-builtin nodes from custom_nodes to user_nodes (Manager installs)
3. Restore missing nodes from ComfyUI-Manager snapshot
4. Install pip deps for all user nodes
"""
import json
import os
import subprocess
import sys

CUSTOM_NODES_DIR = "/app/comfyui/custom_nodes"
USER_NODES_DIR = "/app/user_nodes"
BUILTIN_LIST = "/app/builtin_nodes.txt"
SNAPSHOTS_DIR = os.path.join(CUSTOM_NODES_DIR, "ComfyUI-Manager", "snapshots")


def load_builtin_nodes():
    """Load the list of builtin node directory names."""
    if not os.path.isfile(BUILTIN_LIST):
        return set()
    with open(BUILTIN_LIST, encoding="utf-8") as f:
        return {line.strip() for line in f if line.strip()}


def symlink_user_nodes(builtin_nodes):
    """Create symlinks from user_nodes into custom_nodes."""
    if not os.path.isdir(USER_NODES_DIR):
        return

    count = 0
    for name in os.listdir(USER_NODES_DIR):
        if name in builtin_nodes:
            continue  # Never shadow builtin nodes

        src = os.path.join(USER_NODES_DIR, name)
        dst = os.path.join(CUSTOM_NODES_DIR, name)

        if os.path.islink(dst):
            continue  # Already symlinked

        if os.path.exists(dst):
            # Directory exists (builtin or previously installed) - skip
            continue

        os.symlink(src, dst)
        count += 1
        print(f"  [LINK] {name}")

    if count:
        print(f"[restore_nodes] Symlinked {count} user node(s)")


def migrate_to_user_nodes(builtin_nodes):
    """Move non-builtin, non-symlinked nodes from custom_nodes to user_nodes.

    This captures nodes installed by ComfyUI-Manager during runtime,
    moving them to the persistent user_nodes directory.
    """
    if not os.path.isdir(USER_NODES_DIR):
        os.makedirs(USER_NODES_DIR, exist_ok=True)

    count = 0
    for name in os.listdir(CUSTOM_NODES_DIR):
        if name in builtin_nodes:
            continue
        if name.startswith("."):
            continue

        src = os.path.join(CUSTOM_NODES_DIR, name)
        if not os.path.isdir(src):
            continue  # Only migrate directories (custom node folders)
        if os.path.islink(src):
            continue  # Already a symlink
        if os.path.islink(src):
            continue  # Already a symlink

        dst_in_user = os.path.join(USER_NODES_DIR, name)
        if os.path.exists(dst_in_user):
            continue  # Already in user_nodes

        # Move to user_nodes
        import shutil
        shutil.move(src, dst_in_user)
        # Create symlink back
        os.symlink(dst_in_user, src)
        count += 1
        print(f"  [MIGRATE] {name} -> user_nodes")

    if count:
        print(f"[restore_nodes] Migrated {count} node(s) to user_nodes")


def restore_from_snapshot(builtin_nodes):
    """Restore missing nodes from the latest ComfyUI-Manager snapshot."""
    if not os.path.isdir(SNAPSHOTS_DIR):
        return

    # Find latest snapshot
    snapshots = [f for f in os.listdir(SNAPSHOTS_DIR) if f.endswith(".json")]
    if not snapshots:
        return

    snapshots.sort(
        key=lambda f: os.path.getmtime(os.path.join(SNAPSHOTS_DIR, f)),
        reverse=True,
    )
    snapshot_path = os.path.join(SNAPSHOTS_DIR, snapshots[0])
    print(f"[restore_nodes] Reading snapshot: {os.path.basename(snapshot_path)}")

    with open(snapshot_path, encoding="utf-8") as f:
        snap = json.load(f)

    # Get installed git URLs
    installed_urls = set()
    for name in os.listdir(CUSTOM_NODES_DIR):
        git_dir = os.path.join(CUSTOM_NODES_DIR, name, ".git")
        if not os.path.isdir(git_dir) and not os.path.islink(
            os.path.join(CUSTOM_NODES_DIR, name)
        ):
            continue
        # For symlinks, check the target's .git
        real_path = os.path.realpath(os.path.join(CUSTOM_NODES_DIR, name))
        if os.path.isdir(os.path.join(real_path, ".git")):
            try:
                result = subprocess.run(
                    ["git", "-C", real_path, "config", "remote.origin.url"],
                    capture_output=True, text=True, timeout=5,
                )
                if result.returncode == 0 and result.stdout.strip():
                    installed_urls.add(result.stdout.strip())
            except Exception:
                pass

    # Install missing nodes from snapshot
    git_nodes = snap.get("git_custom_nodes", {})
    missing = {
        url: info for url, info in git_nodes.items()
        if url not in installed_urls and not info.get("disabled", False)
    }

    if not missing:
        print("[restore_nodes] All snapshot nodes already installed.")
        return

    print(f"[restore_nodes] Restoring {len(missing)} node(s) from snapshot...")
    for url, info in missing.items():
        _install_node(url, builtin_nodes)

    print("[restore_nodes] Snapshot restore done.")


def _install_node(url, builtin_nodes):
    """Clone a node to user_nodes and symlink to custom_nodes."""
    repo_name = url.rstrip("/").split("/")[-1].replace(".git", "")

    if repo_name in builtin_nodes:
        return  # Don't reinstall builtins

    target_user = os.path.join(USER_NODES_DIR, repo_name)
    target_link = os.path.join(CUSTOM_NODES_DIR, repo_name)

    if os.path.exists(target_link) or os.path.exists(target_user):
        return

    os.makedirs(USER_NODES_DIR, exist_ok=True)

    print(f"  [CLONE] {repo_name}")
    result = subprocess.run(
        ["git", "clone", url, target_user],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        print(f"  [FAIL] clone: {result.stderr.strip()}")
        return

    # Symlink to custom_nodes
    os.symlink(target_user, target_link)


def install_user_deps():
    """Install pip deps for all user_nodes."""
    if not os.path.isdir(USER_NODES_DIR):
        return

    count = 0
    for name in os.listdir(USER_NODES_DIR):
        req = os.path.join(USER_NODES_DIR, name, "requirements.txt")
        if not os.path.isfile(req):
            continue

        print(f"  [PIP] {name}")
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "-r", req],
            capture_output=True, text=True, timeout=300,
        )
        count += 1

    if count:
        print(f"[restore_nodes] Installed deps for {count} node(s)")


def main():
    builtin = load_builtin_nodes()
    print(f"[restore_nodes] {len(builtin)} builtin nodes in image")

    # Step 1: Migrate any Manager-installed nodes to user_nodes
    print("[restore_nodes] Step 1: Migrating Manager-installed nodes...")
    migrate_to_user_nodes(builtin)

    # Step 2: Symlink user_nodes to custom_nodes
    print("[restore_nodes] Step 2: Symlinking user nodes...")
    symlink_user_nodes(builtin)

    # Step 3: Restore missing nodes from snapshot
    print("[restore_nodes] Step 3: Restoring from snapshot...")
    restore_from_snapshot(builtin)

    # Step 4: Install pip deps for user nodes
    print("[restore_nodes] Step 4: Installing dependencies...")
    install_user_deps()

    print("[restore_nodes] All done.")


if __name__ == "__main__":
    main()
