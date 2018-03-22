//
//  MXRDownloadTask.h
//  NSURLSession_Test
//
//  Created by 周建顺 on 2017/2/10.
//  Copyright © 2017年 周建顺. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ZJSBreakpointDownload;

typedef void (^ZJSURLSessionTaskProgressBlock)(NSProgress * _Nullable progress);
typedef void (^ZJSURLSessionTaskCompletionHandler)(NSURLSessionTask * _Nonnull task, NSString* _Nullable filePath, NSError * _Nullable error);
typedef void (^ZJSURLSessionTaskReceivedBytesBlock)(long long receivedBytes);

@interface ZJSDownloadTask : NSObject

@property (nonatomic, copy, readonly, nonnull) NSString *url;
@property (nonatomic, copy, readonly, nonnull) NSString *destinationFilePath;
@property (nonatomic, copy, readonly, nonnull) NSString *tempFilePath;
//@property (nonatomic) NSInteger taskIdentifier; // task的标识
@property (nonatomic, assign, readonly) unsigned long long  currentLength; // 当前已经下载的大小
@property (nonatomic, assign, readonly) unsigned long long totalLength; // 总大小

@property (nonatomic, weak, nullable) ZJSBreakpointDownload *manager;


@property (nonatomic, copy, nullable) ZJSURLSessionTaskProgressBlock downloadProgressBlock;
@property (nonatomic, copy, nullable) ZJSURLSessionTaskCompletionHandler downloadCompletionBlock;
@property (nonatomic, copy, nullable) ZJSURLSessionTaskReceivedBytesBlock receivedBytesBlock;


-(instancetype _Nullable)initWithDownloadUrl:(NSString* _Nonnull)downloadUrl destinationFilePath:(NSString* _Nonnull)destinationFilePath tempFilePath:(NSString* _Nonnull)tempFilePath currentLength:(long long)currentLength;

- (void)URLSession:(NSURLSession * _Nonnull)session dataTask:(NSURLSessionDataTask * _Nonnull)dataTask
didReceiveResponse:(NSURLResponse * _Nonnull)response
 completionHandler:(void (^ _Nonnull)(NSURLSessionResponseDisposition disposition))completionHandler;

- (void)URLSession:(NSURLSession * _Nonnull)session
          dataTask:(NSURLSessionDataTask * _Nonnull)dataTask
    didReceiveData:(nullable NSData *)data;

- (void)URLSession:(NSURLSession * _Nonnull)session
              task:(NSURLSessionTask * _Nonnull)task
didCompleteWithError:(nullable NSError *)error;

- (void)activeReceivedBytesBlock;

@end
