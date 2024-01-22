# sunrise
**sunrise** is written for Horizon OS's kernel. It has support for FAT32, FAT16, and FAT12 filesystems. Primarily, it is intended to be fairly small, giving some necessary features but leaning towards a small binary size.
## Building
```
# Ubuntu/Debian/Mint

# Toolchain
sudo apt install build-essential bison flex libgmp3-dev libmpc-dev libmpfr-dev texinfo wget

# Scons & Other build tools
sudo apt install python3 python3-pip python3-sh python3-parted scons libguestfs-tools qemu-system-x86 mtools nasm
```

After both sets of packages are installed, simply run ```scons toolchain```. This will build the GCC toolchain in the project root directory.

If issues arise building the GCC toolchain, the best place to consult is the [OsDev Wiki](https://wiki.osdev.org/GCC_Cross-Compiler).

After the toolchain is built, run ```scons``` to build the bootloader. After, to run the bootloader in QEMU, use the ```scons run``` command.

If issues arise with ```libguestfs-tools``` throwing errors during the built process, it may require changing some settings in the ```/etc/fuse.conf``` file to allow non-root users to mount drives. To pass all of these issues, another option is to run as superuser with the command ```sudo scons run``` which will build and run as root, thus bypassing the mounting issues.

To clean the binaries and .obj files, run ```scons -c```.

## Additional information
**sunrise** ships with an example kernel to illustrate how it may be linked with another kernel. To replace with another kernel, follow the same compilation/linking convention followed by the test kernel i.e. using the same ```linker.ld``` file format and formatting the main function in the same way to ensure proper compatibilty.

If errors arise during the build process if switching between building for floppy or disk, removing the ```./build``` folder should remedy these.

## Acknowledgments
**sunrise** is based on the bootloader written for the [nanobyte_os](https://github.com/nanobyte-dev/nanobyte_os) project and takes heavy inspiration on its implementation.
