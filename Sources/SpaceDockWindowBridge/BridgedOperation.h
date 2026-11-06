// Experimental implementation informed by Hammerspoon PR #3889:
// https://github.com/Hammerspoon/hammerspoon/pull/3889
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
@interface NSObject (SpaceDockMovePrototype)
-(instancetype)initWithWindows:(NSArray*)windows spaceID:(uint64_t)space;
@end
static int64_t (*submitMove)(void*);
static void *findMoveSymbol(void) {
 const char *wanted="__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation";
 for(uint32_t i=0;i<_dyld_image_count();i++) {
  const char *path=_dyld_get_image_name(i);if(!path || !strstr(path,"/SkyLight.framework/"))continue;
  const struct mach_header_64 *h=(const void*)_dyld_get_image_header(i);if(h->magic!=MH_MAGIC_64)continue;
  const uint8_t *p=(const void*)(h+1),*end=p+h->sizeofcmds;
  const struct segment_command_64 *link=NULL; const struct symtab_command *table=NULL;
  for(uint32_t j=0;j<h->ncmds && p+sizeof(struct load_command)<=end;j++) {
   const struct load_command *cmd=(const void*)p;
   if(cmd->cmdsize<sizeof(*cmd) || p+cmd->cmdsize>end)return NULL;
   if(cmd->cmd==LC_SEGMENT_64 && cmd->cmdsize>=sizeof(struct segment_command_64)) {
    const struct segment_command_64 *seg=(const void*)p;if(!strncmp(seg->segname,SEG_LINKEDIT,16))link=seg;
   }
   if(cmd->cmd==LC_SYMTAB && cmd->cmdsize>=sizeof(struct symtab_command))table=(const void*)p;
   p+=cmd->cmdsize;
  }
  if(!link||!table)return NULL;
  intptr_t slide=_dyld_get_image_vmaddr_slide(i);uintptr_t base=slide+link->vmaddr-link->fileoff;
  if(table->symoff<link->fileoff || (uint64_t)table->symoff+(uint64_t)table->nsyms*sizeof(struct nlist_64)>link->fileoff+link->filesize || table->stroff<link->fileoff || (uint64_t)table->stroff+table->strsize>link->fileoff+link->filesize)return NULL;
  const struct nlist_64 *symbols=(const void*)(base+table->symoff);const char *strings=(const void*)(base+table->stroff);
  for(uint32_t j=0;j<table->nsyms;j++) {
   uint32_t offset=symbols[j].n_un.n_strx;if(offset>=table->strsize)continue;
   const char *name=strings+offset;size_t available=table->strsize-offset;
   if(memchr(name,0,available) && !strcmp(name,wanted))return (void*)(slide+symbols[j].n_value);
  }
 }
 return NULL;
}
