#import "SHMVideo.h"
#import <sys/shm.h>
#import <sys/time.h>

#define SHM_KEY (196738)

static inline uint32_t GetCurrentTimeInUsec();

@interface SHMVideo (){
	int _mode;
	int _shmid;
	int _width;
	int _height;
	int _bpp;
	int _memsize;
	uint32_t _timestamp;
	void *_sharedMemory;
	void *_videoBuffer;
}
@end

@implementation SHMVideo

@synthesize width = _width;
@synthesize height = _height;
@synthesize bpp = _bpp;
@synthesize sharedMemory = _sharedMemory;
@synthesize videoBuffer = _videoBuffer;

+(id)client{
	return [[[SHMVideo alloc] initWithMode:0] autorelease];
}

+(id)server{
	return [[[SHMVideo alloc] initWithMode:1] autorelease];
}

-(id)initWithMode:(int)mode{
	self = [super init];
	_mode = mode;
	return self;
}

- (void)dealloc
{
    if( _sharedMemory ){
		shmdt(_sharedMemory);
		if( _mode ){
			shmctl(_shmid,IPC_RMID,NULL);
		}
	}
    [super dealloc];
}

-(int)numClients{
	if( _shmid <= 0 ){ return -1; }
	struct shmid_ds ds;
	shmctl(_shmid,IPC_STAT,&ds);
	return ds.shm_nattch-1;
}

-(void*)allocateBuffer{
	if( _mode ){ return NULL; }
	if( _sharedMemory ){
		shmdt(_sharedMemory);
		_sharedMemory = NULL;
		_shmid = 0;
	}
	_width = 0;
	_height = 0;
	_bpp = 0;
	_memsize = 0;
	int shmid = shmget(SHM_KEY, 0, 0666);
	if( shmid < 0 ){
		NSLog(@"Failed to init shared memory");
		return NULL;
	}
	void *ptr = shmat(shmid,NULL,SHM_RDONLY);
	if( ptr == (void*)-1 ){
		NSLog(@"Failed to map shared memory");
		return NULL;
	}
	NSLog(@"SHM: %d %p (%d)\n",shmid,ptr,_mode);
	
	uint32_t *v = (uint32_t*)ptr;
	if( v[0] != SHM_KEY ){
		return NULL;
	}
	
	_width = (int)v[1];
	_height = (int)v[2];
	_bpp = (int)v[3];
	_memsize = (int)v[4];
	_timestamp = v[5];
	_shmid = shmid;
	_sharedMemory = ptr;
	_videoBuffer = v + 8;
	
	return ptr;
}

-(void*)allocateBufferWithSize:(CGSize)size format:(int)bpp{
	if( _mode == 0 ){
		return [self allocateBuffer];
	}
	if( _sharedMemory ){
		shmdt(_sharedMemory);
		shmctl(_shmid,IPC_RMID,NULL);
		_sharedMemory = NULL;
		_shmid = 0;
	}
	_width = (int)size.width;
	_height = (int)size.height;
	_bpp = bpp;
	_memsize = _width*_height*_bpp;
	if( _bpp == 1 ){
		_memsize += _width*_height/2;
	}
	int shmid = shmget(SHM_KEY, _memsize, 0666 | IPC_CREAT );
	if( shmid < 0 ){
		NSLog(@"Failed to init shared memory");
		return NULL;
	}
	void *ptr = shmat(shmid,NULL,0);
	if( ptr == (void*)-1 ){
		NSLog(@"Failed to map shared memory");
		return NULL;
	}
	NSLog(@"SHM: %d %p (%d)\n",shmid,ptr,_mode);
	
	uint32_t *v = (uint32_t*)ptr;
	v[0] = SHM_KEY;
	v[1] = (uint32_t)_width;
	v[2] = (uint32_t)_height;
	v[3] = (uint32_t)_bpp;
	v[4] = (uint32_t)_memsize;
	v[5] = GetCurrentTimeInUsec();
	v[6] = 0;
	v[7] = 0;
	_shmid = shmid;
	_sharedMemory = ptr;
	_videoBuffer = v + 8;
	return ptr;
}

-(void)updateVideoBuffer:(void**)src{
	if( !_sharedMemory ){ return; }
	uint32_t *v = (uint32_t*)_sharedMemory;
	v[5] = GetCurrentTimeInUsec();
	if( src[0] ){
		memcpy(_videoBuffer,src[0],_width*_height*_bpp);
	}
	if( _bpp == 1 && src[1] ){
		memcpy(_videoBuffer+_width*_height,src[1],_width*_height/2);
	}
}

@end

static inline uint32_t GetCurrentTimeInUsec(){
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return ((uint32_t)tv.tv_usec+(uint32_t)tv.tv_sec*1000000);
}
