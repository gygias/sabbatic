//
//  STVerseView.m
//  Sabbatic
//
//  Created by david on 2/19/26.
//

#import "STVerseView.h"

NS_ASSUME_NONNULL_BEGIN

@interface STVerseView ()
@property (strong) NSArray *versesDicts;
@end

@implementation STVerseView

- (void)preload
{
    self.backgroundColor = [STColorClass clearColor];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Verses" ofType:@"plist"];
    self.versesDicts = [NSArray arrayWithContentsOfFile:path];
    NSLog(@"loaded %lu verses from %@",self.versesDicts.count,path);
}

- (NSInteger)_fontSizeForViewWidth:(CGFloat)width
{
    return 10 + ( width / STFontSizeScalar );
}

- (void)drawRect:(CGRect)rect
{
    NSDictionary *aVerseDict = self.versesDicts[arc4random() % self.versesDicts.count];
    NSString *verseString = [NSString stringWithFormat:@"%@\n\t-%@ %@:%@",aVerseDict[@"text"],
                                                                        aVerseDict[@"book"],
                                                                        aVerseDict[@"chapter"],
                                                                        aVerseDict[@"verse"]];
    NSDictionary *attrs = @{ NSForegroundColorAttributeName : [STColorClass grayColor],
                             NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:rect.size.width]] };
    [verseString drawInRect:rect withAttributes:attrs];
    
}

@end

NS_ASSUME_NONNULL_END
