//
//  YTURLProtocol.m
//  WebviewCache
//
//  Created by xidee on 16/3/31.
//  Copyright © 2016年 xidee All rights reserved.
/*
 原理：注册NSURLProtocol，截获app url请求，指定类型的资源文件用本地数据替换,若本地数据没有，则执行下载.
 */

#import "YTURLProtocol.h"
#import <UIKit/UIImage.h>
#import <UIKit/UIDevice.h>

@implementation YTURLProtocol
//这个方法用来返回是否需要处理这个请求，如果需要处理，返回YES，否则返回NO。在该方法中可以对不需要处理的请求进行过滤。
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if ([NSURLProtocol propertyForKey:@"protocolKey" inRequest:request]) {
        return NO;
    }
    NSLog(@"%@",request.URL);
    
    //需要拦截的域名
    NSArray *hosts = @[@"m.yintai.com"];
    //需要拦截的资源类型
    NSArray *suffixs = @[@"html",@"js",@"png",@"jpg",@"css"];
    
    for (NSString *host in hosts) {
        if ([request.URL.host isEqualToString:host]) {
            for (NSString *suffix in suffixs) {
                if ([request.URL.lastPathComponent hasSuffix:suffix]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}
//重写该方法，可以对请求进行修改，例如添加新的头部信息，修改，修改url等，返回修改后的请求。
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}
//该方法主要用来判断两个请求是否是同一个请求，如果是，则可以使用缓存数据，通常只需要调用父类的实现即可
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:( NSURLRequest *)b
{
    return YES;
}
//重写该方法，对于NSURLSession，就是发起一个NSURLSessionTask
- (void)startLoading
{
    NSString *Url = [NSString stringWithFormat:@"%@",self.request.URL];
    
    //文件类型
    NSString *mimiType = @"";
    //编码格式 不同资源类型编码方式不一 防止读写错误
    NSString *textEncodingName = @"UTF8";
    //文件名称
    NSRange range = [Url rangeOfString:@"http://m.yintai.com/"];
    NSString *dataName = [Url stringByReplacingCharactersInRange:range withString:@""];
    
    //取得文件类型 并且去掉后缀
    if([Url.lastPathComponent hasSuffix:@"html"])
    {
        mimiType = [NSString stringWithFormat:@"text/html"];
    }
    
    if([Url.lastPathComponent hasSuffix:@"js"])
    {
        mimiType=[NSString stringWithFormat:@"application/x-javascript"];
    }
    
    if([Url.lastPathComponent hasSuffix:@"png"])
    {
        mimiType=[NSString stringWithFormat:@"image/png"];
        textEncodingName = @"BASE64";
    }
    
    if([Url.lastPathComponent hasSuffix:@"jpg"])
    {
        mimiType=[NSString stringWithFormat:@"image/jpeg"];
        textEncodingName = @"BASE64";
    }
    
    if([Url.lastPathComponent hasSuffix:@"css"])
    {
        mimiType=[NSString stringWithFormat:@"text/css"];
    }
    
    //拼上本地文件夹的名称
    dataName = [NSString stringWithFormat:@"/m.yintai.com/%@",dataName];
    NSString *cachesPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject]stringByAppendingString:dataName];
    NSData *data = [NSData dataWithContentsOfFile:cachesPath];
    if (!data) {
        //证明本地没有该文件 这时候执行下载
        NSLog(@"资源包路径不存在%@",cachesPath);
//        //标记这个request已经请求过 否则会一直重复请求
        NSMutableURLRequest * request = [self.request mutableCopy];
        [NSURLProtocol setProperty:@(YES) forKey:@"protocolKey" inRequest:request];
            NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
            self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
            NSURLSessionDataTask * task = [self.session dataTaskWithRequest:request];
            [task resume];
    }else
    {   //本地有数据直接作为结果返回
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:mimiType expectedContentLength:[data length] textEncodingName:textEncodingName];
        
        [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocol:self didLoadData:data];
        [[self client] URLProtocolDidFinishLoading:self];
    }
}

- (void)stopLoading
{
    [self.session invalidateAndCancel];
    self.session = nil;
}

#pragma mark - NSURLSessionDataDelegate

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler
{
    completionHandler(proposedResponse);
}

@end
