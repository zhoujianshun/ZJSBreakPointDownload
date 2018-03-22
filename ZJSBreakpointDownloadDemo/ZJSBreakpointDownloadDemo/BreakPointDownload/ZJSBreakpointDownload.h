//
//  MXRBreakPointDownload.h
//  NSURLSession_Test
//
//  Created by 周建顺 on 2017/2/10.
//  Copyright © 2017年 周建顺. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface ZJSBreakpointDownload : NSObject

/**
 The managed session.
 */
@property (readonly, nonatomic, strong) NSURLSession *session;

/**
 The operation queue on which delegate callbacks are run.
 */
@property (readonly, nonatomic, strong) NSOperationQueue *operationQueue;

@property (readonly, nonatomic, strong, nullable) NSArray <NSURLSessionTask *> *tasks;


///-------------------------------
/// @name Managing Callback Queues
///-------------------------------

/**
 The dispatch queue for `completionBlock`. If `NULL` (default), the main queue is used.
 */
@property (nonatomic, strong, nullable) dispatch_queue_t completionQueue;

/**
 The dispatch group for `completionBlock`. If `NULL` (default), a private dispatch group is used.
 */
@property (nonatomic, strong, nullable) dispatch_group_t completionGroup;


-(instancetype)init;
-(instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration* _Nullable)sessionConfiguration;
-(void)clear;

/**
 启动一个下载任务

 @param downloadUrl 下载地址
 @param destinationFilePath 下载文件的保存路径
 @param paramResume 是否断点下载
 @param downloadProgressBlock 下载进度变化的回调
 @param receivedBytesBlock 接收到数据的回调
 @param completionHandler 完成的回调
 @return 下载任务
 */
-(NSURLSessionDataTask *)startDownloadFileTaskWithUrl:(NSString*)downloadUrl
                                           toFilePath:(NSString *)destinationFilePath
                                        breakpointResume:(BOOL)paramResume
                                             progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                        receivedBytes:(nullable void (^)(long long receivedBytes))receivedBytesBlock
                                    completionHandler:(nullable void (^)(NSURLSessionTask* _Nonnull task, NSString* _Nullable filePath, NSError * _Nullable error))completionHandler;


/**
 创建一个下载任务

 @param downloadUrl 下载地址
 @param destinationFilePath 下载文件的保存路径
 @param paramResume 是否断点下载
 @param downloadProgressBlock 下载进度变化的回调
 @param receivedBytesBlock 接收到数据的回调
 @param completionHandler 完成的回调
 @return 下载任务
 */
-(NSURLSessionDataTask *)downloadFileTaskWithUrl:(NSString*)downloadUrl
                                      toFilePath:(NSString *)destinationFilePath
                                breakpointResume:(BOOL)paramResume
                                        progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                   receivedBytes:(nullable void (^)(long long receivedBytes))receivedBytesBlock
                               completionHandler:(nullable void (^)(NSURLSessionTask* _Nonnull task, NSString* _Nullable filePath, NSError * _Nullable error))completionHandler;

/**
 Invalidates the managed session, optionally canceling pending tasks.
 
 @param cancelPendingTasks Whether or not to cancel pending tasks.
 */
- (void)invalidateSessionCancelingTasks:(BOOL)cancelPendingTasks;

-(NSString*)getTempFilePathWithUrl:(NSString*)destinationFilePath;

@end
NS_ASSUME_NONNULL_END
