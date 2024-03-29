open transform_Image.m
im1 = imread("Image1.jpg");
im2 = imread("Image2.jpg");

im1 = rgb2gray(im1);
im1 = im2double(im1);

im2 = rgb2gray(im2);
im2 = im2double(im2);

points1 = detectSURFFeatures( im1 );
features1 = extractFeatures( im1,points1 );

points2 = detectSURFFeatures( im2 );
features2 = extractFeatures( im2,points2 );

indexPairs = matchFeatures( features1, features2, "Unique", true );

matchedPoints1 = points1( indexPairs( :,1 ) );
matchedPoints2 = points2( indexPairs( :,2 ) );

im1_points = matchedPoints1.Location;
im2_points = matchedPoints2.Location ;


%test1 = [1373 1204; 1841 1102; 1733 1213; 2099 1297];
%test2 = [182 1160; 728 1055; 617 1172; 1001 1247];

a = estimateTransform(im1_points, im2_points);
a1 = estimateTransformRANSAC(im1_points, im2_points);

im2_transformed = transform_Image( im2, inv(a1), "homography");

nanlocations = isnan( im2_transformed );
im2_transformed( nanlocations )=0;

imshow(im2_transformed);

im1_expanded = zeros(size(im2_transformed));
im1_expanded(1:size(im1, 1), 1:size(im1, 2)) = im1;

imshow(im1_expanded);

[x_overlap,y_overlap]=ginput(2);

overlapleft=round(x_overlap(1));
overlapright=round(x_overlap(2));

ramp = zeros(1, size(im1_expanded,2));
ramp(1, overlapright:end) = ones(1, size(im1_expanded,2)-overlapright+1);
rangesize = overlapright-overlapleft;
ramp(1,overlapleft:overlapright) = 0:1/rangesize:1;
plot(ramp);

im2_blend = im2_transformed .* repmat( ramp,size(im2_transformed,1),1 );
im1_blend = im1_expanded .* repmat( 1-ramp,size(im1_expanded,1),1 );
panorama = im2_blend+ im1_blend;
imshow(panorama);

%% Estimate Transform
function A = estimateTransform( im1_points, im2_points )
P = zeros(size(im1_points, 1), 9);
for i = 1:(size(im1_points))
    P(i*2 - 1, :) = [-1*im1_points(i, 1) -1*im1_points(i, 2) -1 0 0 0 im1_points(i, 1)*im2_points(i, 1) im1_points(i, 2)*im2_points(i, 1) im2_points(i, 1)];
    P(i*2, :) = [0 0 0 -1*im1_points(i, 1) -1*im1_points(i, 2) -1 im1_points(i, 1)*im2_points(i, 2) im1_points(i, 2)*im2_points(i, 2) im2_points(i, 2)];
end
r = zeros(2 * size(im1_points, 1), 1);
if size(P,1) == 8
    [U,S,V] = svd(P);
else
    [U,S,V] = svd(P,'econ');
end

q = V(:,end);


A = [q(1) q(2) q(3); q(4) q(5) q(6); q(7) q(8) q(9)];

end

%% Ransac
function A_rans = estimateTransformRANSAC(im1_points, im2_points)
Nransac = 10000;
t = 3;

n = size(im1_points,1);

k = 4;

nbest = 0;
Abest = [];
idxbest = [];

for i_ransac = 1:Nransac

    % randomly sample set of indices to compute A
    idx = randperm( n,k );

    pts1i = im1_points(idx,:);
    pts2i = im2_points(idx,:);

    A_test = estimateTransform( pts1i,pts2i );

    pts2e = A_test * [im1_points';ones(1,n)];
    pts2e = pts2e(1:2,:) ./ pts2e(3,:);
    pts2e = pts2e';

    d = sqrt((pts2e(:,1)-im2_points(:,1)).^2 + (pts2e(:,2)-im2_points(:,2)).^2);

    idxgood = d < t;
    ngood = sum(idxgood);
    %Agood = A_test;

    if ngood > nbest
        nbest = ngood;
        %Abest = Agood;
        idxbest = idxgood;
    end
end

pts1inliers = im1_points(idxbest,:);
pts2inliers = im2_points(idxbest,:);

A_inliers = estimateTransform( pts1inliers, pts2inliers );
A_rans = A_inliers;
end