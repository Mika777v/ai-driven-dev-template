package com.example;

public class Main {
    static String name(String s) {
        return s.trim();
    }
    public static void main(String[] args) {
        try {
            name(null);
        } catch (Exception e) {
            throw new IllegalStateException("wrap", e);
        }
    }
}
