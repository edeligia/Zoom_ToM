% 0 is both, 1 is likely laptop and 2 is likely second screen 
screen_number = max(Screen('Screens'));
screen_rect = [];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

image_path = [pwd filesep 'ABOQ3690.jpg']; 
image = imread(image_path);

 window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
 
imageTexture = Screen('MakeTexture', window, image);

Screen('DrawTexture', window, imageTexture, [], [], 0);

Screen('Flip', window);

WaitSecs(2);

sca;
sca;
