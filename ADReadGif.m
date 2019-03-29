//
//  ADReadGif.m
//  anbang_ios
//
//  Created by 王奥东 on 17/5/24.
//  Copyright © 2017年 ch. All rights reserved.
//

#import "ADReadGif.h"
#import "UIImage+GIF.h"
#import <ImageIO/ImageIO.h>

@implementation ADReadGif


//比SD的加载节约1.3M内存，测试图为16KB的CustomMJHeaderTopGif
+(UIImage *)ad_imageWithSmallGIFName:(NSString *)gifName scale:(CGFloat)scale {
    
    
    CGFloat scales = [UIScreen mainScreen].scale;
    
    NSData *data;
    if (scales > 1.0f) {
        
        if (scales == 2.0f) {
            
            NSString *retinaPath = [[NSBundle mainBundle] pathForResource:[gifName stringByAppendingString:@"@2x"] ofType:@"gif"];
            
            data = [NSData dataWithContentsOfFile:retinaPath];
        } else {
            NSString *retinaPath = [[NSBundle mainBundle] pathForResource:[gifName stringByAppendingString:@"@3x"] ofType:@"gif"];
            
            data = [NSData dataWithContentsOfFile:retinaPath];
        }
    }else {
        NSString *path = [[NSBundle mainBundle] pathForResource:gifName ofType:@"gif"];
        
        data = [NSData dataWithContentsOfFile:path];
    }
    if (data) {
        return [ADReadGif ad_imageWithSmallGIFData:data scale:1];
    }else {
        return [UIImage imageNamed:gifName];
    }
    
    
}



+ (UIImage *)ad_imageWithSmallGIFData:(NSData *)data scale:(CGFloat)scale {
    
    
    //根据data数据创建图片资源数据
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFTypeRef)(data), NULL);
    if (!source) {
        return nil;
    }
    //返回图像源`isrc'中的图像数量（不包括缩略图）
    size_t count = CGImageSourceGetCount(source);
    //图像数量小于等于1代表不是动态图片
    if (count <= 1) {
        CFRelease(source);
        return [UIImage imageWithData:data scale:scale];
    }
    
    NSUInteger frames[count];//每张图片的动画时间为多少50FPS
    double oneFrameTime = 1 / 50.0;//每张图片最少的动画时间50fps
    NSTimeInterval totalTime = 0;//GIF动画总时间
    NSUInteger totalFrame = 0;//总共需要多少*50FPS
    NSUInteger gcdFrame = 0;
    //    frames[i]/gcdFrame = 不断播放则第i张图片需要多少张图片
    
    for (size_t i = 0; i < count; i++) {
        //GIF动画中每张图片存在的时间
        NSTimeInterval delay = _ad_CGImageSourceGetGIFFrameDelayAtIndex(source, i);
        totalTime += delay;
        //lrint四舍五入，第一位小数为准
        NSInteger frame = lrint(delay / oneFrameTime);
        //最少为50fps
        if (frame < 1) {
            frame = 1;
        }
        frames[i] = frame;
        totalFrame += frames[i];
        if (i==0) {
            gcdFrame = frames[i];
        }else {
            NSUInteger frame = frames[i],tmp;
            if (frame < gcdFrame) {
                tmp = frame; frame = gcdFrame; gcdFrame = tmp;
            }
            while (true) {
                tmp = frame % gcdFrame;
                if (tmp==0)  break;
                frame = gcdFrame;
                gcdFrame = tmp;
            }
        }
    }
    NSMutableArray *array = [NSMutableArray new];
    for (size_t i = 0; i < count; i++) {
        //在图像源`isrc'中的`index'处返回图像。 索引是从零开始的。
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
        //图片不能为空
        if (!imageRef) {
            CFRelease(source);
            return nil;
        }
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        //宽高不能为0
        if (width == 0 || height == 0) {
            CFRelease(source);
            CFRelease(imageRef);
            return nil;
        }
        //获取图片的透明度
        CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask;
        BOOL hasAlpha = NO;//是否含有透明通道
        //RGBA | ARGB | 没有透明度的RGBA | 没有透明度的ARGB
        if (alphaInfo == kCGImageAlphaPremultipliedLast || alphaInfo == kCGImageAlphaPremultipliedFirst || alphaInfo == kCGImageAlphaLast || alphaInfo == kCGImageAlphaFirst) {
            hasAlpha = YES;
        }
        // BGRA8888 (premultiplied) or BGRX8888
        // 等同于 UIGraphicsBeginImageContext() and -[UIView drawRect:]
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
        //ARGB | XRGB
        bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        //CGBitmapContextCreate 位图上下文，第一个参数data如果为NULL则指向一个至少为bytesPerRow * height的内存块。第二个与第三个参数width/height指像素宽/像素高，也就是位图上下文的宽高,  第四个参数bitsPerComponent，每个像素的字节数等于（bitsPerComponent *组件数+ 7）/ 8 ,第五个参数bytesPerRow位图的每一行由bytesPerRow字节组成，每个组件的数量像素由`space'指定，也可以指定目标颜色配置文件,第七个参数`bitmapInfo'指定位图是否应该包含 alpha通道及其如何生成，以及是否组件是浮点或整数。
        CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, bitmapInfo);
        CGColorSpaceRelease(space);
        if (!context) {
            CFRelease(source);
            CFRelease(imageRef);
            return nil;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);//decode
        //根据位图上下文返回一个CGImage图像
        CGImageRef decoded = CGBitmapContextCreateImage(context);
        CFRelease(context);
        if (!decoded) {
            CFRelease(source);
            CFRelease(imageRef);
            return nil;
        }
        UIImage *image = image = [UIImage imageWithCGImage:decoded scale:scale orientation:UIImageOrientationUp];
        CGImageRelease(imageRef);
        CGImageRelease(decoded);
        if (!image) {
            CFRelease(source);
            return nil;
        }
        for (size_t j = 0, max = frames[i]/gcdFrame;j < max; j++) {
            [array addObject:image];
        }
    }
    CFRelease(source);
    UIImage *image = [UIImage animatedImageWithImages:array duration:totalTime];
    return image;
}

static NSTimeInterval _ad_CGImageSourceGetGIFFrameDelayAtIndex(CGImageSourceRef source,size_t index) {
    NSTimeInterval delay = 0;
    //返回图像源`isrc'中的`index'处的图像属性。 索引是从零开始的。
    CFDictionaryRef dic = CGImageSourceCopyPropertiesAtIndex(source, index, NULL);
    if (dic) {
        CFDictionaryRef dicGIF = CFDictionaryGetValue(dic, kCGImagePropertyGIFDictionary);
        if (dicGIF) {
            //获取GIF分隔开的动画时间
            NSNumber *num = CFDictionaryGetValue(dicGIF, kCGImagePropertyGIFUnclampedDelayTime);
            //__FLT_EPSILON__最小正数值
            if (num.doubleValue <= __FLT_EPSILON__) {
                //动画时间
                num = CFDictionaryGetValue(dicGIF, kCGImagePropertyGIFDelayTime);
            }
            delay = num.doubleValue;
        }
        CFRelease(dic);
    }
    //动画时间最少为0.1
    if (delay < 0.02) {
        delay = 0.1;
    }
    return delay;
}

@end
