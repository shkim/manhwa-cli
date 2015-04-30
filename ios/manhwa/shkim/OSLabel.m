//
//  OSLabel.m
//  sleek
//
//  Created by shkim on 9/8/14.
//  Copyright (c) 2014 shkim. All rights reserved.
//

#import "OSLabel.h"
#import <QuartzCore/QuartzCore.h>

// http://stackoverflow.com/questions/9502235/how-to-add-padding-left-on-a-uilabel-created-programmatically

@interface OSLabel ()
{
	UIEdgeInsets m_insets;
}

@end

@implementation OSLabel

- (void)setEdgeInsets:(UIEdgeInsets)insets andCornerRadius:(CGFloat)radius
{
	m_insets = insets;
	
	//self.backgroundColor = [UIColor grayColor];
	self.layer.cornerRadius = radius;
	self.layer.masksToBounds = YES;
	//self.layer.borderWidth = 1;
	//self.layer.borderColor = [[UIColor darkGrayColor] CGColor];

}

- (void)drawTextInRect:(CGRect)rect
{
	[super drawTextInRect:UIEdgeInsetsInsetRect(rect, m_insets)];
}

- (CGSize)intrinsicContentSize
{
	CGSize size = [super intrinsicContentSize];
	size.width  += m_insets.left + m_insets.right;
	size.height += m_insets.top + m_insets.bottom;
	return size;
}

@end
