/// libBIL top-level interface
/// @file libbfd.idl
/// @author Sang Kil Cha <sangkil.cha\@gmail.com>

/*
Copyright (c) 2014, Sang Kil Cha
All rights reserved.
This software is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License version 2, with the special exception on linking
described in file LICENSE.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

#include "libbfd.h"

#include <bfd.h>
#include <dis-asm.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

void error_exit( const char* msg )
{
    fprintf( stderr, "%s\n", msg );
    exit( 1 );
}

bfdp new_bfd( const char* filename, int arch )
{
    enum bfd_architecture _arch = (enum bfd_architecture) arch;
    bfdp p = bfd_openr( filename, NULL );
    if ( !p ) error_exit( "failure: bfd_openr" );


    bfd_set_arch_info( p, bfd_lookup_arch(_arch, 0) );
    return p;
}

int delete_bfd( bfdp abfd )
{
    return (int) bfd_close_all_done( abfd );
}

disasp new_disasm_info( bfdp abfd,
                        char* buffer,
                        int len,
                        unsigned long long addr )
{
    struct disassemble_info *di =
      (struct disassemble_info *) malloc( sizeof(struct disassemble_info) );
    if ( !di )
        error_exit( "failed to allocate disassemble_info" );

    init_disassemble_info( di, stdout, (fprintf_ftype) fprintf );

    di->flavour = bfd_get_flavour( abfd );
    di->arch = bfd_get_arch( abfd );
    di->mach = bfd_get_mach( abfd );
    di->octets_per_byte = bfd_octets_per_byte( abfd );
    di->disassembler_needs_relocs = FALSE;

    if ( bfd_big_endian( abfd ) )
        di->display_endian = di->endian = BFD_ENDIAN_BIG;
    else if ( bfd_little_endian ( abfd ) )
        di->display_endian = di->endian = BFD_ENDIAN_LITTLE;

    disassemble_init_for_target( di );

    di->buffer = (bfd_byte*) malloc( len );
    di->buffer_vma = (bfd_vma) addr;
    di->buffer_length = len;
    di->section = NULL;

    if ( !di->buffer )
        error_exit( "failed to allocate disassemble_info.buffer" );
    memcpy( di->buffer, buffer, len );

    return di;
}

void delete_disasm_info( disasp di )
{
    if ( di ) {
        free( di->buffer );
        free( di );
        di = NULL;
    }
}

struct bprintf_buffer {
    char *str; // the start of the string
    char *end; // the null terminator at the end of the written string.
    size_t size; // the size of str
};

int bprintf( struct bprintf_buffer *dest, const char *fmt, ... )
{
    va_list ap;
    int ret;
    size_t size_left = dest->size - (dest->end - dest->str);
    va_start(ap, fmt);
    ret = vsnprintf(dest->end, size_left, fmt, ap);
    va_end(ap);
    if (ret >= size_left) {
        // we seem to need to call va_start again... is this legal?
        dest->size = dest->size+ret+1-size_left;
        char *str = (char*)realloc( dest->str, dest->size );

        assert( str ); // this code is full of xalloc anyways...

        dest->end = str + (dest->end - dest->str);
        dest->str = str;
        size_left = dest->size - (dest->end - dest->str);
        va_start(ap, fmt);
        ret = vsnprintf( dest->end, size_left, fmt, ap );
        va_end(ap);
        assert(ret == size_left-1 && ret > 0);
    }
    dest->end += ret;
    return ret;
}

char* disasm( bfdp abfd,
              disasp di,
              unsigned long long addr )
{
    static struct bprintf_buffer bits = {NULL, NULL, 0};

    disassembler_ftype disas = disassembler( abfd );
    fprintf_ftype old_fprintf_func = di->fprintf_func;
    void *oldstream = di->stream;
    di->fprintf_func = (fprintf_ftype) bprintf;
    di->stream = &bits;

    bits.end = bits.str;

    disas( addr, di );

    di->fprintf_func = old_fprintf_func;
    di->stream = oldstream;

    return bits.str;
}

