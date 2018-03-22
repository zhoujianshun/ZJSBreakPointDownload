//
//  MXRDownloadTask.m
//  NSURLSession_Test
//
//  Created by 周建顺 on 2017/2/10.
//  Copyright © 2017年 周建顺. All rights reserved.
//

#import "ZJSDownloadTask.h"
#import "ZJSBreakpointDownload.h"

static dispatch_group_t mxr_url_session_manager_completion_group() {
    static dispatch_group_t mxr_url_session_manager_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mxr_url_session_manager_completion_group = dispatch_group_create();
    });
    
    return mxr_url_session_manager_completion_group;
}

@interface ZJSDownloadTask()

@property (nonatomic, assign) unsigned long long totalLength;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, strong, nullable) NSOutputStream *outStream; // 输出流

@end

@implementation ZJSDownloadTask

-(instancetype)initWithDownloadUrl:(NSString*)downloadUrl destinationFilePath:(NSString*)destinationFilePath tempFilePath:(NSString*)tempFilePath currentLength:(long long)currentLength{
    self = [super init];
    if (self) {
        _url = downloadUrl;
        _destinationFilePath = destinationFilePath;
        _tempFilePath = tempFilePath;
        _currentLength = currentLength;
        [self setup];
    }
    
    return self;

}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    [self setup];

    return self;
}

-(void)dealloc{
    [self.outStream close];
    self.outStream = nil;
    [self removeObservers];
    self.manager = nil;
}

-(void)setup{
    self.downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    self.downloadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    [self addObservers];
}



#pragma mark - getter and setter

-(void)setCurrentLength:(unsigned long long)currentLength{
    _currentLength = currentLength;
    
    if (self.receivedBytesBlock) {
        self.receivedBytesBlock(_currentLength);
    }
    
    self.downloadProgress.completedUnitCount = _currentLength;
}

-(void)setTotalLength:(unsigned long long)totalLength{
    _totalLength = totalLength;
    self.downloadProgress.totalUnitCount = _totalLength;
}

#pragma mark - observers
-(void)addObservers{
    [self.downloadProgress addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               options:NSKeyValueObservingOptionNew
                               context:NULL];
}

-(void)removeObservers{
    [self.downloadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted)) context:NULL];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if (object == self.downloadProgress) {
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(self.downloadProgress);
        }
    }
}


#pragma mark - 公开方法

- (void)activeReceivedBytesBlock{
    if (self.receivedBytesBlock) {
        self.receivedBytesBlock(_currentLength);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    // 1.设置输出流
    self.outStream = [[NSOutputStream alloc] initToFileAtPath:self.tempFilePath append:YES];

    [self.outStream open];
    // 2.设置文件的总大小
    self.totalLength = self.currentLength + response.expectedContentLength;
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.outStream write:(uint8_t *)data.bytes maxLength:data.length];
    self.currentLength = self.currentLength + data.length;
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{

    [self.outStream close];
    self.outStream = nil;
    if (self.manager.completionQueue) {
        // 如果设置了completionQueue，则在completionQueue中执行。这里和afnetworking存在差异af中不设置默认是在主线程中执行
        dispatch_group_async(self.manager.completionGroup?:mxr_url_session_manager_completion_group(), self.manager.completionQueue?:dispatch_get_main_queue(), ^{
            if (self.downloadCompletionBlock) {
                self.downloadCompletionBlock(task, self.destinationFilePath, error);
            }
        });
    }else{
        if (self.downloadCompletionBlock) {
            self.downloadCompletionBlock(task, self.destinationFilePath, error);
        }
    }

}




@end
