module Math

export polyval

polyval(coeffs, x) = sum(i -> coeffs[i] * x ^ (i - 1), length(coeffs):-1:1)

geocentric_lla2cart(lat, lon, alt; EarthRadius=6.3781E6) = geodeodetic_lla2cart(lat, lon, alt, EarthRadius, EarthRadius)
function geodeodetic_lla2cart(ϕ, λ, h, a, b)                     #lat, lon, height
    N = a^2 / sqrt((a*cosd(ϕ))^2 + (b*sind(ϕ))^2)
    x = (N + h)*cosd(ϕ)*cosd(λ)
    y = (N + h)*cosd(ϕ)*sind(λ)
    z = ((b/a)^2*N + h)*sind(ϕ)

    (x, y, z)
end

end

