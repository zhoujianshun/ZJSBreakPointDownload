//
//  MXRBreakPointDownload.m
//  NSURLSession_Test
//
//  Created by 周建顺 on 2017/2/10.
//  Copyright © 2017年 周建顺. All rights reserved.
//

#import "ZJSBreakpointDownload.h"

#import "ZJSDownloadTask.h"

#import <UIKit/UIKit.h>

//#define DLOG(...) NSLog(__VA_ARGS__);

#pragma mark ----start解决ios8以前taskIdentifier不一定惟一的bug，造成下载完成的回调错误的问题

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug 1140.11
#else
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug NSFoundationVersionNumber_iOS_8_0
#endif



static dispatch_queue_t mxr_url_session_manager_creation_queue(){
    static dispatch_queue_t mxr_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mxr_url_session_manager_creation_queue = dispatch_queue_create("com.mxrcorp.MXRBreakPointDownload.session.manager.creation", DISPATCH_QUEUE_SERIAL);
    });
    
    return mxr_url_session_manager_creation_queue;
}

static void mxr_url_session_manager_creat_task_safely(dispatch_block_t block){
    if (NSFoundationVersionNumber< NSFoundationVersionNumber_With_Fixed_5871104061079552_bug) {
        
        // AFNetworking中对bug的描述：
        // Fix of bug
        // Open Radar:http://openradar.appspot.com/radar?id=5871104061079552 (status: Fixed in iOS8)
        // Issue about:https://github.com/AFNetworking/AFNetworking/issues/2093
        dispatch_sync(mxr_url_session_manager_creation_queue(), block);
    }else{
        block();
    }
    
}




#pragma mark ----end解决ios8以前taskIdentifier不一定惟一的bug

static NSString *MXRBreakPointDownloadLockName = @"com.mxrcorp.MXRBreakPointDownloadLock";
#define MXRBreakPointDownloadTimeout 30 // 连接超时事件

@interface ZJSBreakpointDownload()<NSURLSessionDataDelegate>

@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (readwrite, nonatomic, strong) NSURLSession *session;
@property (readwrite, nonatomic, strong) NSOperationQueue *operationQueue;// 回调在此队列执行

@property (nonatomic, strong) NSLock *lock;

@property (nonatomic, strong) NSMutableDictionary *mutableMXRTasksKeyedByTaskIdentifier;



@end

@implementation ZJSBreakpointDownload

-(instancetype)init{
    return [self initWithSessionConfiguration:nil];
}

-(void)dealloc{
}

-(void)clear{
    [self.session invalidateAndCancel];
    self.session= nil;
}

-(instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration*)sessionConfiguration{
    self = [super init];
    if (self) {
        
        if (!sessionConfiguration) {
            sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        
        self.sessionConfiguration = sessionConfiguration;
        
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
        
        self.lock = [[NSLock alloc] init];
        self.lock.name = MXRBreakPointDownloadLockName;
        
        
        self.mutableMXRTasksKeyedByTaskIdentifier = [NSMutableDictionary new];
        
    }
    return self;
}


-(NSURLSessionDataTask *)startDownloadFileTaskWithUrl:(NSString*)downloadUrl
                                           toFilePath:(NSString *)destinationFilePath
                                     breakpointResume:(BOOL)paramResume
                                             progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                        receivedBytes:(nullable void (^)(long long receivedBytes))receivedBytesBlock
                                    completionHandler:(nullable void (^)(NSURLSessionTask* _Nonnull task, NSString* _Nullable filePath, NSError * _Nullable error))completionHandler{
    
    NSURLSessionDataTask *task = [self downloadFileTaskWithUrl:downloadUrl toFilePath:destinationFilePath breakpointResume:paramResume progress:downloadProgressBlock receivedBytes:receivedBytesBlock completionHandler:completionHandler];
    [task resume];
    return task;
}


-(NSURLSessionDataTask *)downloadFileTaskWithUrl:(NSString*)downloadUrl
                                           toFilePath:(NSString *)destinationFilePath
                                     breakpointResume:(BOOL)paramResume
                                             progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                        receivedBytes:(nullable void (^)(long long receivedBytes))receivedBytesBlock
                                    completionHandler:(nullable void (^)(NSURLSessionTask* _Nonnull task, NSString* _Nullable filePath, NSError * _Nullable error))completionHandler{
    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 正在下载的文件缓存地址
    NSString *tempFilePath = [self getTempFilePathWithUrl:destinationFilePath];
    if (!paramResume) {
        // 如果不需要断点续传，删除temp文件
        if ([fileManager fileExistsAtPath:tempFilePath]) {
            NSError *error;
            [fileManager removeItemAtPath:tempFilePath error:&error];
            if (error) {
                NSLog(@"%@ file remove failed!\nError:%@", tempFilePath, error);
            }
        }
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:downloadUrl]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:MXRBreakPointDownloadTimeout];
    //request.timeoutInterval = 15.f;
    request.HTTPMethod = @"GET";
    NSString *userAgent = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
#if TARGET_OS_IOS
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
#elif TARGET_OS_WATCH
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; watchOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[WKInterfaceDevice currentDevice] model], [[WKInterfaceDevice currentDevice] systemVersion], [[WKInterfaceDevice currentDevice] screenScale]];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    userAgent = [NSString stringWithFormat:@"%@/%@ (Mac OS X %@)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
#pragma clang diagnostic pop
    if (userAgent) {
        if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSMutableString *mutableUserAgent = [userAgent mutableCopy];
            if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false)) {
                userAgent = mutableUserAgent;
            }
        }
        
        [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
 
    }

    
    unsigned long long fileSize = 0;
    // 判断之前是否下载过 如果有下载重新构造Header
    if ([fileManager fileExistsAtPath:tempFilePath]) {
        NSError *error = nil;
        fileSize = [[fileManager attributesOfItemAtPath:tempFilePath
                                                  error:&error]
                    fileSize];
        if (error) {
            NSLog(@"get %@ fileSize failed!\nError:%@", tempFilePath, error);
        }
        NSString *headerRange = [NSString stringWithFormat:@"bytes=%llu-", fileSize];
        [request setValue:headerRange forHTTPHeaderField:@"Range"];
    }
    
    // 确保文件下载的文件夹存在
    [self makeSureDirectoryExist:[tempFilePath stringByDeletingLastPathComponent]];
   
    __block NSURLSessionDataTask *task;
    __weak typeof(self) weakSelf = self;
    mxr_url_session_manager_creat_task_safely(^{
        task = [weakSelf.session dataTaskWithRequest:request];
    });
    ZJSDownloadTask *mxrTask = [[ZJSDownloadTask alloc] initWithDownloadUrl:downloadUrl destinationFilePath:destinationFilePath tempFilePath:tempFilePath currentLength:fileSize];
    mxrTask.manager = self;
    mxrTask.downloadProgressBlock = downloadProgressBlock;
    mxrTask.downloadCompletionBlock = completionHandler;
    mxrTask.receivedBytesBlock = receivedBytesBlock;
    
    // 所有回调都需要在self.operationQueue中执行
    [self.operationQueue addOperationWithBlock:^{
        [mxrTask activeReceivedBytesBlock];
    }];
    
    [self addMXRTask:mxrTask forTask:task];
    
    return task;
}

-(void)invalidateSessionCancelingTasks:(BOOL)cancelPendingTasks{
    dispatch_async(dispatch_get_main_queue(), ^{
        
//        [self.mutableMXRTasksKeyedByTaskIdentifier enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
//            MXRDownloadTask *mxrTask = obj;
//            mxrTask.downloadProgressBlock = nil;
//            mxrTask.downloadCompletionBlock = nil;
//            mxrTask.receivedBytesBlock = nil;
//        }];
        if (cancelPendingTasks) {
            [self.session invalidateAndCancel];
        }else{
            [self.session finishTasksAndInvalidate];
        }
    });
}


#pragma mark - tasks

- (NSArray *)tasksForKeyPath:(NSString *)keyPath {
    __block NSArray *tasks = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(dataTasks))]) {
            tasks = dataTasks;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(uploadTasks))]) {
            tasks = uploadTasks;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(downloadTasks))]) {
            tasks = downloadTasks;
        } else
            if ([keyPath isEqualToString:NSStringFromSelector(@selector(tasks))]) {
            tasks = [@[dataTasks, uploadTasks, downloadTasks] valueForKeyPath:@"@unionOfArrays.self"];
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return tasks;
}

-(NSArray<NSURLSessionTask *> *)tasks{
    return [self tasksForKeyPath:NSStringFromSelector(_cmd)];
}


#pragma mark - mxrTasks

- (void)addMXRTask:(ZJSDownloadTask *)mxrTask forTask:(NSURLSessionTask *)task{
    NSParameterAssert(task);
    NSParameterAssert(mxrTask);
    [self.lock lock];
    self.mutableMXRTasksKeyedByTaskIdentifier[@(task.taskIdentifier)] = mxrTask;
    [self.lock unlock];
}


-(ZJSDownloadTask *)mxrTaskforTask:(NSURLSessionTask *)task{
    NSParameterAssert(task);
    
    ZJSDownloadTask *mxrTask;
    [self.lock lock];
    mxrTask =  self.mutableMXRTasksKeyedByTaskIdentifier[@(task.taskIdentifier)];
    [self.lock unlock];
    
    return mxrTask;
}

-(void)removeMXRTaskforTask:(NSURLSessionTask *)task{
    NSParameterAssert(task);
    [self.lock lock];
    [self.mutableMXRTasksKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
    [self.lock unlock];
}


#pragma mark - NSURLSessionDataDelegate
/* The task has received a response and no further messages will be
 * received until the completion block is called. The disposition
 * allows you to cancel a request or to turn a data task into a
 * download task. This delegate message is optional - if you do not
 * implement it, you can get the response as a property of the task.
 *
 * This method will not be called for background upload tasks (which cannot be converted to download tasks).
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    // 收到响应
    ZJSDownloadTask *mxrTask = [self mxrTaskforTask:dataTask];
    [mxrTask URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

/* Sent when data is available for the delegate to consume.  It is
 * assumed that the delegate will retain and not copy the data.  As
 * the data may be discontiguous, you should use
 * [NSData enumerateByteRangesUsingBlock:] to access it.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{

    ZJSDownloadTask *mxrTask = [self mxrTaskforTask:dataTask];
    [mxrTask URLSession:session dataTask:dataTask didReceiveData:data];

}


#pragma mark - NSURLSessionTaskDelegate
/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    ZJSDownloadTask *mxrTask = [self mxrTaskforTask:task];
    

    if (error) {
        NSLog(@"下载出错：%@", error.localizedDescription);
    }else{

        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if ([fileManager fileExistsAtPath:mxrTask.destinationFilePath]) {
            [fileManager removeItemAtPath:mxrTask.destinationFilePath error:NULL];
        }
        
        NSString *dir = [mxrTask.destinationFilePath stringByDeletingLastPathComponent];
        [self makeSureDirectoryExist:dir];
        
        NSError *error;
        [fileManager moveItemAtPath:mxrTask.tempFilePath toPath:mxrTask.destinationFilePath error:&error];
        if (error) {
            NSLog(@"%@ move temp file from %@ to %@ error:%@", mxrTask.url, mxrTask.tempFilePath, mxrTask.destinationFilePath, error.localizedDescription);
        }
    }
    NSLog(@"status code:%@",@(((NSHTTPURLResponse*)task.response).statusCode));
    [mxrTask URLSession:session task:task didCompleteWithError:error];
    
    [self removeMXRTaskforTask:task];

}

#pragma mark - tempFile相关



/**
 删除resumeData
 
 @param destinationFilePath 下载的目标文件保存的路径
 */
-(void)removerTempFileWithUrl:(NSString*)destinationFilePath{
    NSString *path = [self getTempFilePathWithUrl:destinationFilePath];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}



/**
 获取resumeData保存的路径
 
 @param destinationFilePath 下载的目标文件保存的路径
 @return resumeData保存的路径
 */
-(NSString*)getTempFilePathWithUrl:(NSString*)destinationFilePath{
    NSString *path =  [destinationFilePath stringByAppendingPathExtension:@"zjstemp"];
    return path;
}


#pragma mark -----------------
- (void) makeSureDirectoryExist:(NSString *)directoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExit = [fileManager fileExistsAtPath:directoryPath isDirectory:&isDir];
    if (!(isDirExit&&isDir))
    {
        NSError * fError = nil;
        BOOL result = [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&fError];
        
        if ( !result )
        {
#if defined(DEBUG)
            NSLog(@"获取书本fileList创建目录:%@失败，原因:%@",directoryPath,fError);
#endif
        }
    }
}


@end
