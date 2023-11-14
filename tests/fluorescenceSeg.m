function maskout = fluorescenceSeg(I, opts)

mask = I > max(I(:))/ opts.thFactor;

mask = bwareaopen(mask, 300);

mask = imopen(mask, strel('disk', 10));

dd = imcomplement(double(medfilt2(I, [10 10])));
dd(~mask) = -Inf;
dd = imhmin(dd, 45);

LL = watershed(dd);
%LL = LL - 1;

maskout = mask;
maskout(LL == 0) = 0;
maskout = bwareaopen(maskout, 300);


end