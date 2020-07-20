#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int main(int argc, char* argv[])
{
    int file = -1, ret = -1;
    unsigned char vals[4];

    if (argc == 1)
    {
        file = STDIN_FILENO;
    }
    else if (argc == 2)
    {
        file = open(argv[1], O_RDONLY);
        if (file == -1)
        {
            ret = errno;
            goto done;
        }
    }
    else
    {
        fprintf(stderr, "file-magic <filename>\n");
        ret = EBADF;
        goto done;
    }

    vals[0] = vals[1] = vals[2] = vals[3] = 0;
    ret = read(file, vals, 4);

    fprintf(stdout, "%02X%02X%02X%02X\n",
        vals[0], vals[1], vals[2], vals[3]);

    ret = 0;

done:

    if (file != -1)
        close (file);

    return ret;
}