#import "QTCamera.h"
#import <QTKit/QTKit.h>

static void ConvertARGBtoYUV(uint8_t *y, uint8_t *uv, uint8_t *rgba, int w, int h );
static void ConvertARGBtoBGRA(uint8_t *bgra, uint8_t *rgba, int w, int h );

@interface QTCamera () {
	int _width;
	int _height;
	int _bpp;
	int _fps;
	QTCameraCallback _callback;
	void *_callbackContext;
	QTCaptureSession *_session;
	QTMovie *_movie;
	NSTimer *_movieTimer;
	void    *_videoBuffers[2];
	uint8_t *_rawBuffer;
}
@end

@implementation QTCamera

@synthesize width = _width;
@synthesize height = _height;
@synthesize bpp = _bpp;

+(NSArray*)enumerateCameras{
	NSArray *devices = [QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo];
	NSMutableArray *list = [NSMutableArray array];
	for( QTCaptureDevice *device in devices ){
		[list addObject:[device localizedDisplayName]];
	}
	NSLog(@"%@",list);
	return list;
}

-(id)init{
	self = [super init];
	_width = 640;
	_height = 480;
	_bpp = 1;
	_fps = 30;
	return self;
}

- (void)dealloc{
	[self cleanup];
    [super dealloc];
}

-(void)cleanup{
	if( [_session isRunning] ){
		[_session stopRunning];
	}
	[_session release];
	_session = nil;
	if( [_movieTimer isValid] ){
		[_movieTimer invalidate];
	}
	[_movieTimer release];
	_movieTimer = nil;
	[_movie release];
	_movie = nil;
	[self deallocateRawBuffer];
}

-(void)setFrameRate:(int)fps{
	_fps = fps;
}

-(void)setCaptureSize:(NSSize)size format:(int)bpp{
	_width = (int)size.width;
	_height = (int)size.height;
	_bpp = bpp;
}

-(void)setInputSource:(id)source{
	[self cleanup];
	NSError *error = nil;
	if( [source isKindOfClass:[NSNumber class]] ){
		_session = [[QTCaptureSession alloc] init];
		NSArray *devices = [QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo];
		QTCaptureDevice  *videoDevice = [devices objectAtIndex:[(NSNumber*)source intValue]];
		[videoDevice open:nil];
		QTCaptureDeviceInput *input = [QTCaptureDeviceInput deviceInputWithDevice:videoDevice];
		QTCaptureDecompressedVideoOutput *output = [[QTCaptureDecompressedVideoOutput alloc] init];
		[_session addInput:input error:nil];
		[_session addOutput:output error:nil];
	}else if( [source isKindOfClass:[NSString class]] ){
		_movie = [[QTMovie movieWithFile:source error:&error] retain];
	}else{
		NSLog(@"Unsupported source type");
	}
}

-(void)setCaptureCallback:(QTCameraCallback)callback context:(void *)context{
	_callback = callback;
	_callbackContext = context;
}

-(BOOL)isRunning{
	if( [_session isRunning] || [_movieTimer isValid] ){
		return YES;
	}
	return NO;
}

-(void)start{
	if( _session ){
		if( [_session isRunning] ){ return; }
		if( _fps == 0 ){ _fps = 30; }
		QTCaptureDecompressedVideoOutput *output = [[_session outputs] objectAtIndex:0];
		[output setMinimumVideoFrameInterval:1.0/_fps];
		[output setAutomaticallyDropsLateVideoFrames:YES];
		[output setDelegate:self];		
		uint32_t format = 0;
		if( _bpp == 4 ){
			format = kCVPixelFormatType_32BGRA;
		}else{
			format = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
			_bpp = 1;
		}
		[output setPixelBufferAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
										  [NSNumber numberWithDouble:_width], (id)kCVPixelBufferWidthKey,
										  [NSNumber numberWithDouble:_height], (id)kCVPixelBufferHeightKey,
										  [NSNumber numberWithUnsignedInt:format],
										  (id)kCVPixelBufferPixelFormatTypeKey, nil]];
		[_session startRunning];
		[self allocateRawBuffer];
	}else if( _movie ){
		if( _movieTimer ){
			if( [_movieTimer isValid] ){ return; }
			[_movieTimer release];
			_movieTimer = nil;
		}
		if( _fps > 0 ){
			_movieTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0/_fps
															target:self
														  selector:@selector(movieTimerCallback)
														  userInfo:nil repeats:YES] retain];
		}else{
			_movieTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0/30.0
															target:self
														  selector:@selector(movieTimerCallback)
														  userInfo:nil repeats:NO] retain];
		}
		[self allocateRawBuffer];
	}
}

-(void)stop{
	if( _session ){
		[_session stopRunning];
		[[[_session outputs] objectAtIndex:0] setDelegate:nil];
	}else if( _movie ){
		if( [_movieTimer isValid] ){
			[_movieTimer invalidate];
		}
		[_movieTimer release];
		_movieTimer = nil;
	}
}

-(void)reset{
	if( _movie ){
		[_movie setCurrentTime:QTMakeTime(0,1)];
		[self movieTimerCallback];
	}
}

-(void)nextFrame{
	if( _movie && ![_movieTimer isValid] ){
		QTTime tm = [_movie currentTime];
		int dt =  (int)tm.timeScale/30;
		QTTime nt = QTMakeTime(tm.timeValue+dt,tm.timeScale);
		[_movie setCurrentTime:nt];
		[self movieTimerCallback];
	}
}

-(void)prevFrame{
	if( _movie && ![_movieTimer isValid] ){
		QTTime tm = [_movie currentTime];
		int dt =  (int)tm.timeScale/30;
		QTTime nt = QTMakeTime(tm.timeValue-dt,tm.timeScale);
		[_movie setCurrentTime:nt];
		[self movieTimerCallback];
	}
}

-(void)captureOutput:(QTCaptureOutput *)captureOutput
  didOutputVideoFrame:(CVImageBufferRef)videoFrame
	 withSampleBuffer:(QTSampleBuffer *)sampleBuffer
	   fromConnection:(QTCaptureConnection *)connection{
	CGSize size = CVImageBufferGetDisplaySize(videoFrame);
	int w = (int)size.width;
	int h = (int)size.height;
	if( w!=_width || h!=_height ){ return; }
	CVPixelBufferLockBaseAddress(videoFrame, 0);
	int buffsize = _width*_height*_bpp;
	if( _bpp == 1 ){
		_videoBuffers[0] = _rawBuffer;
		_videoBuffers[1] = _rawBuffer + buffsize;
		memcpy(_videoBuffers[0],CVPixelBufferGetBaseAddressOfPlane(videoFrame,0),buffsize);
		memcpy(_videoBuffers[1],CVPixelBufferGetBaseAddressOfPlane(videoFrame,1),buffsize/2);
	}else if( _bpp == 4 ){
		_videoBuffers[0] = _rawBuffer;
		_videoBuffers[1] = NULL;
		memcpy(_videoBuffers[0],CVPixelBufferGetBaseAddress(videoFrame),buffsize);
	}
	CVPixelBufferUnlockBaseAddress(videoFrame,0);
	if( _callback ){
		_callback(self,_videoBuffers,_callbackContext);
	}
}

-(void)movieTimerCallback{
	if( !_movie ){ return; }
	NSError *err = nil;
	NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
						  QTMovieFrameImageTypeCVPixelBufferRef,QTMovieFrameImageType,
						  [NSNumber numberWithBool:YES],QTMovieFrameImageHighQuality,
						  [NSValue valueWithSize:NSMakeSize(_width,_height)], QTMovieFrameImageSize,
						  nil];
	QTTime currentTime = [_movie currentTime];
	CVImageBufferRef videoFrame = [_movie frameImageAtTime:currentTime withAttributes:attr error:&err];
	if( err ){
		NSLog(@"QTDecodeError: %@",err);
		return;
	}
	CGSize size = CVImageBufferGetDisplaySize(videoFrame);
	int w = (int)size.width;
	int h = (int)size.height;
	if( w!=_width || h!=_height ){ return; }
	CVPixelBufferLockBaseAddress(videoFrame, 0);
	int buffsize = _width*_height*_bpp;
	void *ptr = CVPixelBufferGetBaseAddress(videoFrame);
	if( _bpp == 1 ){
		_videoBuffers[0] = _rawBuffer;
		_videoBuffers[1] = _rawBuffer + buffsize;
		ConvertARGBtoYUV(_videoBuffers[0], _videoBuffers[1], ptr, w, h);
	}else if( _bpp == 4 ){
		_videoBuffers[0] = _rawBuffer;
		_videoBuffers[1] = NULL;
		ConvertARGBtoBGRA(_videoBuffers[0], ptr, w, h);
	}
	CVPixelBufferUnlockBaseAddress(videoFrame,0);
	if( _callback ){
		_callback(self,_videoBuffers,_callbackContext);
	}
	if( _fps > 0 && [_movieTimer isValid] ){
		long tv = (currentTime.timeValue*_fps)/currentTime.timeScale;
		[_movie setCurrentTime:QTMakeTime(tv+1,_fps)];
	}
	if( QTTimeCompare([_movie duration],[_movie currentTime]) == 0 ){
		if( [_movieTimer isValid] ){
			[_movieTimer invalidate];
		}
	}
}

-(void)allocateRawBuffer{
	if( _rawBuffer ){
		free(_rawBuffer);
		_rawBuffer = NULL;
	}
	if( _width*_height*_bpp == 0 ){
		return;
	}
	if( _bpp == 1 ){
		_rawBuffer = (uint8_t*)malloc(_width*_height+_width*_height/2);
	}else{
		_rawBuffer = (uint8_t*)malloc(_width*_height*_bpp);
	}
}

-(void)deallocateRawBuffer{
	if( _rawBuffer ){
		free(_rawBuffer);
		_rawBuffer = NULL;
	}
	_videoBuffers[0] = NULL;
	_videoBuffers[1] = NULL;
}

@end

static void ConvertARGBtoBGRA(uint8_t *bgra, uint8_t *rgba, int w, int h ){
	for (int i=0; i<h; i++) {
		for (int j=0; j<w; j++) {
			*(bgra+0) = *(rgba+3);
			*(bgra+1) = *(rgba+2);
			*(bgra+2) = *(rgba+1);
			*(bgra+3) = *(rgba+0);
			rgba+=4;
			bgra+=4;
		}
	}
}

static void ConvertARGBtoYUV(uint8_t *y, uint8_t *uv, uint8_t *rgba, int w, int h ){
	for (int i=0; i<h; i++) {
		for (int j=0; j<w; j++) {
			*(y++) = *(rgba+2);
			rgba+=4;
		}
	}
	memset(uv, 128, w*h/2);
}



