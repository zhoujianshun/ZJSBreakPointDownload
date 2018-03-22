//
//  ViewController.m
//  ZJSBreakpointDownload
//
//  Created by 周建顺 on 2018/3/22.
//  Copyright © 2018年 mxrcorp. All rights reserved.
//

#import "ViewController.h"

#import "ZJSBreakpointDownload.h"

@interface ViewController ()
@property (strong, nonatomic) IBOutlet UITextField *fileTextField;
@property (strong, nonatomic) IBOutlet UILabel *progressLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UIButton *startButton;
@property (strong, nonatomic) IBOutlet UIButton *deleteButton;

@property (strong, nonatomic) NSURLSessionTask *task;

@property (nonatomic, strong) ZJSBreakpointDownload *downloader;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.fileTextField.text = @"https://books.mxrcorp.cn/34FE6A60F8724B9CBA13C3A3D841F7F2/others.zip";
    
    self.downloader = [[ZJSBreakpointDownload alloc] init];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)startAction:(id)sender {
    NSString *url = self.fileTextField.text;
    if (!url) {
        return;
    }
    
    if (self.task) {
        [self.task cancel];
        self.task = nil;
    }else{
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
    }
    

}
- (IBAction)deleteAction:(id)sender {
    NSString *url = self.fileTextField.text;
    if (!url) {
        return;
    }
    
    NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *path =[homePath stringByAppendingPathComponent:[url lastPathComponent]];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (error) {
        self.progressLabel.text = @"删除失败";
    }else{
        self.progressLabel.text = @"删除完成";
    }
}


@end
