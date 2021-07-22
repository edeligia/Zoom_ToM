
cd('C:\Users\evade\Documents\Zoom_project\Stims-Redcay+Rice\text_files');
screen_number = max(Screen('Screens'));
screen_rect = [ ];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;
Screen('Preference', 'SkipSyncTests', 1);
scrnRes     = Screen('Resolution',screen_number);               % Get Screen resolution
[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.
window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);

Screen('TextSize', window, screen_font_size);

% DrawFormattedText(window, ' ', 'center', 'center', screen_colour_text);
Screen('Flip', window);

trial = 1;
% empty_text		= ' ';
% Screen('DrawText', window, empty_text ,x0 ,y0);
% Screen('Flip', window);

questionname = sprintf('%d_question.txt', trial);
textfid			= fopen(questionname);
lCounter		= 1;	
while 1
			tline		= fgetl(textfid);							% read line from text file.
			if ~ischar(tline), break, end
 			Screen('DrawText',window, tline, x0-380,y0-160+lCounter*45,[255]);
			lCounter	= lCounter + 1;
end
fclose(textfid);
Screen('Flip', window);

