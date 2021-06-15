clearvars
clc

xx = linspace(0, 10*pi, 42);
yy = sin(2 * pi /5 .* xx);

bfr = BioformatsImage('teto_red50_xy0002.nd2');

vid = VideoWriter('animatedPlot.avi');
open(vid)

for ii = 1:numel(xx)

    I = getPlane(bfr, 1, 2, ii);
    I = imcrop(I, [100 50 400 400]);
        
%     I = double(I);
%     I = (I - min(I(:)))/(max(I(:)) - min(I(:)));
        
    subplot(2, 1, 1);
    imshow(I, [])
    annotation('arrow', [round(rand(1)) 0.1], [round(rand(1)), 0.2]);

    subplot(2, 1, 2)
    plot(xx(1:ii), yy(1:ii), 'b', xx(ii), yy(ii), 'ro');
    xlim([0 35]);
    ylim([-1 1]);
    
    F = getframe(gcf);

    writeVideo(vid, F)

end
close(vid)