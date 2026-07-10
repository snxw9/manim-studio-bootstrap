#define _GNU_SOURCE
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <fcntl.h>
#include <string.h>

int statx(int dirfd, const char *pathname, int flags,
          unsigned int mask, struct statx *statxbuf) {
    struct stat st;
    int fstatat_flags = 0;
    if (flags & AT_SYMLINK_NOFOLLOW) fstatat_flags |= AT_SYMLINK_NOFOLLOW;
    if (flags & AT_EMPTY_PATH) fstatat_flags |= AT_EMPTY_PATH;
    if (fstatat(dirfd, pathname, &st, fstatat_flags) != 0) {
        return -1;
    }
    memset(statxbuf, 0, sizeof(*statxbuf));
    statxbuf->stx_mask = STATX_BASIC_STATS;
    statxbuf->stx_blksize = (unsigned int)st.st_blksize;
    statxbuf->stx_nlink = (unsigned int)st.st_nlink;
    statxbuf->stx_uid = st.st_uid;
    statxbuf->stx_gid = st.st_gid;
    statxbuf->stx_mode = st.st_mode;
    statxbuf->stx_ino = st.st_ino;
    statxbuf->stx_size = (unsigned long long)st.st_size;
    statxbuf->stx_blocks = (unsigned long long)st.st_blocks;
    statxbuf->stx_atime.tv_sec = st.st_atime;
    statxbuf->stx_mtime.tv_sec = st.st_mtime;
    statxbuf->stx_ctime.tv_sec = st.st_ctime;
    statxbuf->stx_rdev_major = major(st.st_rdev);
    statxbuf->stx_rdev_minor = minor(st.st_rdev);
    statxbuf->stx_dev_major = major(st.st_dev);
    statxbuf->stx_dev_minor = minor(st.st_dev);
    return 0;
}
