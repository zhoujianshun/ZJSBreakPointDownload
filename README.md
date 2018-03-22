# ZJSBreakPointDownload
使用NSUrlSession实现的断点续传

        NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
        NSString *path =[homePath stringByAppendingPathComponent:[url lastPathComponent]];
        __weak typeof(self) weakSelf = self;
        self.task = [self.downloader startDownloadFileTaskWithUrl:url toFilePath:path breakpointResume:YES progress:^(NSProgress * _Nonnull downloadProgress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.progressView.progress = downloadProgress.fractionCompleted;
                self.progressLabel.text = [NSString stringWithFormat:@"%@",@(downloadProgress.fractionCompleted)];
            });
        } receivedBytes:^(long long receivedBytes) {
            
        } completionHandler:^(NSURLSessionTask * _Nonnull task, NSString * _Nullable filePath, NSError * _Nullable error) {
            if (!error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.progressLabel.text = @"完成";
                });
            }
            [self.task cancel];
            self.task = nil;
            
        }];
