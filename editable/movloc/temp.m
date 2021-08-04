%% param
TRIGGER_CABLE_COM_STRING = 'COM43';

%% open serial port for stim tracker
sport=serial(TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
fopen(sport);

%send a trigger
%most likely just a byte byte
%1 = 1
%2 = 2
%4 = 3
%...
%3 = 1 and 2
fwrite(sport,['mh',1,0]); %send trigger to Stim Tracker
WaitSecs(1); %PTB command, could use built-in, doesn't have to be 1sec, a few msec is fine
fwrite(sport,['mh',0,0]); %turn trigger off (for StimTracker)

%close connection
fclose(sport);