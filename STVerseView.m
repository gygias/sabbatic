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
@property (strong) NSDictionary *drawAttrs;

@property (strong) NSString *text;
@property NSInteger animationIdx;
@property (strong) NSString *bookChapterVerse;
@property CGFloat fadeIdx;
@end

#define STVerseFadeFrames 5

@implementation STVerseView

- (void)preload
{
    self.backgroundColor = [STColorClass clearColor];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Verses" ofType:@"plist"];
    self.versesDicts = [NSArray arrayWithContentsOfFile:path];
    NSLog(@"loaded %lu verses from %@",self.versesDicts.count,path);
        
    self.drawAttrs = @{ NSForegroundColorAttributeName : [STColorClass grayColor],
                        NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:self.frame.size.width]] };
    
    self.animationIdx = -1;
    self.fadeIdx = 0.0;
}

- (NSInteger)_fontSizeForViewWidth:(CGFloat)width
{
    return 10 + ( width / STFontSizeScalar );
}

- (void)drawRect:(CGRect)rect
{
    if ( self.animationIdx == -1 ) {
        NSDictionary *aVerseDict = self.versesDicts[arc4random() % self.versesDicts.count];
        self.text = aVerseDict[@"text"];
        self.bookChapterVerse = [NSString stringWithFormat:@"%@ %@:%@",aVerseDict[@"book"],
                                                                     aVerseDict[@"chapter"],
                                                                     aVerseDict[@"verse"]];
        self.animationIdx = 0;
    }
    
    NSString *verseString = [self.text substringToIndex:self.animationIdx];
    [verseString drawInRect:rect withAttributes:self.drawAttrs];
    
    if ( self.animationIdx < self.text.length ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.animationIdx++;
            [self setNeedsDisplay];
        });
    } else {
        CGRect textRect = [verseString boundingRectWithSize:rect.size options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:self.drawAttrs context:NULL];
        CGFloat bookChapterVerseXOffset = 25;
        CGFloat lineHeight = [self.bookChapterVerse sizeWithAttributes:self.drawAttrs].height;
        CGRect bookChapterVerseRect = CGRectMake(rect.origin.x + bookChapterVerseXOffset, rect.origin.y + textRect.size.height + lineHeight, rect.size.width - bookChapterVerseXOffset, rect.size.height - textRect.size.height - lineHeight);
        if ( self.fadeIdx < STVerseFadeFrames ) {
            NSDictionary *fadeAttrs = @{ NSForegroundColorAttributeName : [[STColorClass grayColor] colorWithAlphaComponent:(self.fadeIdx / STVerseFadeFrames)],
                                         NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:self.frame.size.width]] };
            [self.bookChapterVerse drawInRect:bookChapterVerseRect withAttributes:fadeAttrs];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.fadeIdx++;
                [self setNeedsDisplay];
            });
        } else {
            [self.bookChapterVerse drawInRect:bookChapterVerseRect withAttributes:self.drawAttrs];
            self.fadeIdx = 0;
            self.animationIdx = -1;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self setNeedsDisplay];
            });
        }
    }
}

@end

NS_ASSUME_NONNULL_END
