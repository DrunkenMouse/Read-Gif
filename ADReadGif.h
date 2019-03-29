//
//  ADReadGif.h
//  anbang_ios
//
//  Created by 王奥东 on 17/5/24.
//  Copyright © 2017年 ch. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ADReadGif : NSObject

+(UIImage *)ad_imageWithSmallGIFName:(NSString *)gifName scale:(CGFloat)scale ;

//Gif图Data数据源与scale
+ (UIImage *)ad_imageWithSmallGIFData:(NSData *)data scale:(CGFloat)scale;
@end
