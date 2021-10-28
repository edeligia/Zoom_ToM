%% open serial port for stim tracker
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial('COM5','BaudRate',115200);
    fopen(sport);
WaitSecs(1);

    fwrite(sport, ['mh',bin2dec('00000001'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 

WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('00000010'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 

WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('00000100'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
    
WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('00001000'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 

WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('00010000'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
    
WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('00100000'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
    
WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('01000000'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 

WaitSecs(5);

    fwrite(sport, ['mh',bin2dec('10000000'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 

WaitSecs(5);

fclose(sport);

