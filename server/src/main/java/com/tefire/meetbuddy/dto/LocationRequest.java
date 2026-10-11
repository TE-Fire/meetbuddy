package com.tefire.meetbuddy.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class LocationRequest {

    @NotNull
    private BigDecimal lng;

    @NotNull
    private BigDecimal lat;
}
