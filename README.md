# Linux.Midrashim
This is my first x64 ELF infector written in full Assembly. It's contains a non destructive payload and will infect other ELF ([PIE](https://en.wikipedia.org/wiki/Position-independent_code) is also supported) on current directory only and not recursively. It uses `PT_NOTE to PT_LOAD` infection technique.


# Build
Assemble it with [FASM](https://flatassembler.net).
```
$ fasm Linux.Midrashim.asm
flat assembler  version 1.73.25  (16384 kilobytes memory, x64)
3 passes, 2631 bytes.

$ file Linux.Midrashim
ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, stripped

$ sha256sum Linux.Midrashim
8f1a835ad6f5c58b397109e28409ec0556d6d374085361c6525f73d5ca5785eb  Linux.Midrashim
```

# References:
- https://www.symbolcrash.com/2019/03/27/pt_note-to-pt_load-injection-in-elf
- https://www.wikidata.org/wiki/Q6041496
- https://legacyofkain.fandom.com/wiki/Ozar_Midrashim
- https://en.wikipedia.org/wiki/Don%27t_Be_Afraid_(album)
