#import <AppKit/AppKit.h>

@protocol GLViewDelegate <NSObject>
@optional
-(void)glViewDrawFrame;
@end

@interface GLView : NSOpenGLView
@property (nonatomic,assign) id<GLViewDelegate> delegate;
@property (nonatomic,retain) NSArray *acceptFileTypes;
-(void)bindContext;
-(void)flush;
-(void)requestRender;
-(GLuint)initTextureWithSize:(CGSize)size format:(int)fmt;
-(void)updateTexture:(GLuint)texId withSize:(CGSize)size format:(int)fmt buffer:(uint8_t*)buffer;
-(NSOpenGLContext*)createShareContext;
@end
